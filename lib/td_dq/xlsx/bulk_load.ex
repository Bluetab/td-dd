defmodule TdDq.XLSX.BulkLoad do
  @moduledoc """
  XLSX Bulk Load Implementations

  This module provides functionality to process XLSX data for implementation bulk operations.
  """

  alias TdCache.DomainCache
  alias TdCache.I18nCache
  alias TdCache.TemplateCache
  alias TdCore.Search.IndexWorker
  alias TdDfLib.Parser
  alias TdDq.Implementations
  alias TdDq.Rules
  alias Truedat.XLSX.BulkLoadProtocol

  require Logger

  @basic_implementation %{
    "dataset" => [],
    "executable" => false,
    "implementation_type" => "basic",
    "population" => [],
    "validations" => []
  }

  defimpl BulkLoadProtocol, for: Implementations.Implementation do
    alias TdDq.XLSX.BulkLoad

    @required_headers [
      "implementation_key",
      "implementation_template",
      "domain_external_id",
      "result_type",
      "goal",
      "minimum"
    ]
    @extra_headers ["rule"]
    @discarded_headers [
      "domain",
      "executable",
      "rule_template",
      "records",
      "errors",
      "result",
      "execution",
      "last_execution_at",
      "inserted_at",
      "updated_at",
      "business_concepts",
      "structure_domains"
    ]
    def get_opts(_) do
      {:ok, domain_ext_id_map} = DomainCache.external_id_to_id_map()

      [
        required_headers: @required_headers,
        extra_headers: @extra_headers,
        discarded_headers: @discarded_headers,
        translate_fn: &I18nCache.get_definition(&2, "ruleImplementations.props.#{&1}"),
        extra_context: %{domain_ext_id_map: domain_ext_id_map}
      ]
    end

    def bulk_load_item(_scope, implementation, ctx) do
      BulkLoad.upsert_implementation(implementation, ctx)
    end

    def on_complete(_impl, ids) do
      IndexWorker.reindex(:implementations, Enum.uniq(ids))
    end

    def sheets_to_templates(_impl_for, sheets) do
      sheets
      |> Enum.map(fn df_name ->
        {:ok, template} = TemplateCache.get_by_name(df_name)
        {df_name, template}
      end)
      |> Enum.reject(fn
        {_, nil} -> true
        _ -> false
      end)
    end
  end

  def upsert_implementation(implementation, ctx) do
    domain_external_id = Map.get(implementation, "domain_external_id")

    df_name = Map.get(implementation, "implementation_template")

    implementation =
      implementation
      |> Map.put("df_name", df_name)
      |> Map.delete("implementation_template")

    with {:domain, domain_id} when is_integer(domain_id) <-
           {:domain, Map.get(ctx.domain_ext_id_map, domain_external_id)},
         {:template, %{} = template_data} <-
           {:template, Map.get(ctx.templates, df_name)} do
      %{
        translations: tft,
        content_schema: content_schema
      } = template_data

      df_content =
        Enum.reduce(implementation["df_content"], %{}, fn {key, value}, acc ->
          case tft[key] do
            nil -> Map.put(acc, key, value)
            t_key -> Map.put(acc, t_key, value)
          end
        end)

      formatted_content =
        Parser.format_content(%{
          content: df_content,
          content_schema: content_schema,
          domain_ids: [domain_id],
          lang: ctx.lang
        })

      %{"implementation_key" => implementation_key} =
        params =
        implementation
        |> Map.put("status", ctx.to_status)
        |> Map.put("domain_id", domain_id)
        |> Map.put("df_content", formatted_content)
        |> translate_result_type(ctx)

      [implementation_key]
      |> Implementations.last_by_keys()
      |> write_implementation(params, ctx)
    else
      {:domain, _} ->
        {:error, {"invalid_domain_external_id", %{domain_external_id: domain_external_id}}}

      {:template, _} ->
        {:error, {"invalid_template_name", %{template_name: df_name}}}
    end
  end

  defp write_implementation([], params, ctx) do
    case create_basic_implementation(params, ctx) do
      {:ok, %{implementation: %{id: id}}} ->
        {:created,
         {id,
          %{
            id: id,
            implementation_key: params["implementation_key"]
          }}}

      {:error, :invalid_rule, rule_name} ->
        {:error,
         {"invalid_associated_rule",
          %{
            rule_name: rule_name
          }}}

      {:error, :implementation, %{errors: errors}, _} ->
        {:error, {"implementation_creation_error", errors}}

      error ->
        Logger.error("unexpected error: #{inspect(error)}")
        :error
    end
  end

  defp write_implementation([implementation], params, ctx) do
    file_data =
      params
      |> Map.get("df_content")
      |> Enum.reject(fn {_, %{"origin" => origin}} -> origin == "default" end)
      |> Map.new()

    df_content =
      (implementation.df_content || %{})
      |> Map.merge(file_data, fn
        _, %{"value" => value} = old, %{"value" => value} -> old
        _, _, new -> new
      end)

    df_content_changes =
      file_data
      |> Enum.reject(fn {key, %{"value" => value}} ->
        (implementation.df_content || %{})
        |> Map.get(key, %{})
        |> Map.get("value")
        |> Kernel.==(value)
      end)
      |> Map.new()

    params = Map.put(params, "df_content", df_content)

    result =
      Implementations.maybe_update_implementation(
        implementation,
        params,
        ctx.claims,
        true
      )

    handle_update_result(result, implementation, params, df_content_changes)
  end

  defp handle_update_result({:ok, %{error: :implementation_unchanged}}, implementation, params, _) do
    {:unchanged,
     %{
       id: implementation.id,
       implementation_key: params["implementation_key"]
     }}
  end

  defp handle_update_result(
         {:ok, %{implementation: %{id: id}, changes: changes}},
         implementation,
         params,
         df_content_changes
       ) do
    changes =
      case changes do
        %{df_content: %{}} -> Map.put(changes, :df_content, df_content_changes)
        changes -> changes
      end

    {:updated,
     {id,
      %{
        id: implementation.id,
        implementation_key: params["implementation_key"],
        changes: changes
      }}}
  end

  defp handle_update_result({:error, _, %{errors: errors}, _}, _, _, _) do
    {:error, {"implementation_creation_error", errors}}
  end

  defp handle_update_result({:error, {_, :deprecated}}, implementation, params, _) do
    {:unchanged,
     %{
       id: implementation.id,
       implementation_key: params["implementation_key"]
     }}
  end

  defp handle_update_result(error, _, _, _) do
    Logger.error("unexpected error: #{inspect(error)}")
    :error
  end

  defp translate_result_type(params, ctx) do
    result_type = Map.get(params, "result_type")
    i18n_key_prefix = "ruleImplementations.props.result_type."

    result_type =
      result_type
      |> I18nCache.get_definitions_by_value(ctx.lang, prefix: i18n_key_prefix)
      |> case do
        [%{definition: _, message_id: key} | _] ->
          key
          |> String.split(".")
          |> List.last()

        [] ->
          result_type
      end

    Map.put(params, "result_type", result_type)
  end

  defp create_basic_implementation(params, ctx) do
    @basic_implementation
    |> Map.merge(params)
    |> create_implementation(ctx)
  end

  defp create_implementation(
         %{"rule" => rule_name} = imp,
         ctx
       )
       when is_binary(rule_name) and rule_name != "" do
    case Rules.get_rule_by_name(rule_name) do
      nil ->
        {:error, :invalid_rule, rule_name}

      rule ->
        Implementations.create_implementation(
          rule,
          imp,
          ctx.claims,
          true
        )
    end
  end

  defp create_implementation(imp, ctx) do
    Implementations.create_ruleless_implementation(imp, ctx.claims, true)
  end
end
