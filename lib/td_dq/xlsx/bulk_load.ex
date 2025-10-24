defmodule TdDq.XLSX.BulkLoad do
  @moduledoc """
  XLSX Bulk Load Implementations

  This module provides functionality to process XLSX data for implementation bulk operations.
  """

  alias TdCache.DomainCache
  alias TdCache.I18nCache
  alias TdCache.TemplateCache
  alias TdDfLib.Format
  alias TdDfLib.Parser
  alias TdDq.Implementations
  alias TdDq.Implementations.Search.Indexer
  alias TdDq.Implementations.UploadEvents
  alias TdDq.Rules

  require Logger

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

  @basic_implementation %{
    "dataset" => [],
    "executable" => false,
    "implementation_type" => "basic",
    "population" => [],
    "validations" => []
  }

  def bulk_load(raw_sheets, ctx) do
    {:ok, domain_ext_id_map} = DomainCache.external_id_to_id_map()
    required_headers = translate_headers(@required_headers, ctx.lang)

    headers =
      @extra_headers
      |> translate_headers(ctx.lang)
      |> Map.merge(required_headers)

    discarded_headers = translate_headers(@discarded_headers, ctx.lang)

    ctx =
      Map.merge(ctx, %{
        required_headers: required_headers,
        headers: headers,
        discarded_headers: discarded_headers,
        domain_ext_id_map: domain_ext_id_map
      })

    {valid_sheets, invalid_sheet_count} = validate_sheets_headers(raw_sheets, ctx)
    impl_params = parse_sheets(valid_sheets, ctx)

    templates =
      impl_params
      |> fetch_templates()
      |> parse_templates(ctx.lang)

    ctx = Map.put(ctx, :templates, templates)

    {inserted_ids, updated_ids, error_count, unchanged_count} =
      upsert_implementations(impl_params, ctx)

    Indexer.reindex(inserted_ids ++ updated_ids)

    {:ok,
     %{
       insert_count: length(inserted_ids),
       update_count: length(updated_ids),
       error_count: error_count,
       unchanged_count: unchanged_count,
       invalid_sheet_count: invalid_sheet_count
     }}
  end

  defp translate_headers(headers, lang) do
    headers
    |> Enum.map(&{I18nCache.get_definition(lang, "ruleImplementations.props.#{&1}") || &1, &1})
    |> Enum.reject(fn
      {nil, _} -> true
      _ -> false
    end)
    |> Map.new()
  end

  defp validate_sheets_headers(sheets, ctx) do
    Enum.reduce(sheets, {[], 0}, fn {sheet_name, {headers, _rows}} = sheet,
                                    {valid_sheets, invalid_count} ->
      if validate_sheet_headers(sheet_name, headers, ctx) do
        {valid_sheets ++ [sheet], invalid_count}
      else
        {valid_sheets, invalid_count + 1}
      end
    end)
  end

  defp validate_sheet_headers(sheet_name, headers, ctx) do
    ctx.required_headers
    |> Map.keys()
    |> Enum.reject(&Enum.member?(headers, &1))
    |> case do
      [] ->
        true

      missing_headers ->
        UploadEvents.create_error(ctx.job_id, %{
          type: "missing_required_headers",
          sheet: sheet_name,
          details: %{missing_headers: missing_headers}
        })

        false
    end
  end

  defp parse_sheets(sheets, ctx) do
    Enum.flat_map(sheets, fn {sheet_name, {headers, rows}} ->
      Enum.with_index(rows, &parse_row(&1, &2, headers, sheet_name, ctx))
    end)
  end

  defp parse_row(row, index, headers, sheet_name, ctx) do
    discarded_headers = Map.keys(ctx.discarded_headers)
    known_headers = Map.keys(ctx.headers)

    df_name_header =
      I18nCache.get_definition(ctx.lang, "ruleImplementations.props.implementation_template") ||
        "implementation_template"

    headers
    |> Enum.zip(row)
    |> Enum.reduce(%{"df_content" => %{}}, fn {header, value}, acc ->
      cond do
        header == df_name_header ->
          Map.put(acc, "df_name", value)

        Enum.member?(discarded_headers, header) ->
          acc

        Enum.member?(known_headers, header) ->
          known_header = Map.get(ctx.headers, header)
          Map.put(acc, known_header, value)

        true ->
          Map.update!(
            acc,
            "df_content",
            &Map.put(&1, header, %{"value" => value, "origin" => "file"})
          )
      end
    end)
    |> Map.merge(%{
      "_sheet" => sheet_name,
      "_row_number" => index + 2
    })
  end

  defp fetch_templates(impl_params) do
    impl_params
    |> Enum.map(& &1["df_name"])
    |> Enum.uniq()
    |> Enum.map(fn df_name ->
      {:ok, template} = TemplateCache.get_by_name(df_name)
      {df_name, template}
    end)
    |> Enum.reject(fn
      {_, nil} -> true
      _ -> false
    end)
    |> Map.new()
  end

  defp parse_templates(templates, lang) do
    Enum.into(templates, %{}, fn {df_name, template} ->
      content_schema = Format.flatten_content_fields(template.content, lang)
      translations = Enum.into(content_schema, %{}, &{&1["definition"], &1["name"]})

      {df_name, %{template: template, translations: translations, content_schema: content_schema}}
    end)
  end

  defp upsert_implementations(impl_params, ctx) do
    impl_params
    |> Enum.map(&upsert_implementation(&1, ctx))
    |> Enum.reduce(
      {[], [], 0, 0},
      fn
        :error, {ids, updated_ids, errors, unchanged_count} ->
          {ids, updated_ids, errors + 1, unchanged_count}

        :unchanged, {ids, updated_ids, errors, unchanged_count} ->
          {ids, updated_ids, errors, unchanged_count + 1}

        {:created, id}, {ids, updated_ids, errors, unchanged_count} ->
          {[id | ids], updated_ids, errors, unchanged_count}

        {:updated, id}, {ids, updated_ids, errors, unchanged_count} ->
          {ids, [id | updated_ids], errors, unchanged_count}
      end
    )
  end

  defp upsert_implementation(implementation, ctx) do
    domain_external_id = Map.get(implementation, "domain_external_id")
    df_name = Map.get(implementation, "df_name")

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
        UploadEvents.create_error(ctx.job_id, %{
          type: "invalid_domain_external_id",
          sheet: implementation["_sheet"],
          row_number: implementation["_row_number"],
          details: %{
            domain_external_id: domain_external_id
          }
        })

        :error

      {:template, _} ->
        UploadEvents.create_error(ctx.job_id, %{
          type: "invalid_template_name",
          sheet: implementation["_sheet"],
          row_number: implementation["_row_number"],
          details: %{
            template_name: df_name
          }
        })

        :error
    end
  end

  defp write_implementation([], params, ctx) do
    case create_basic_implementation(params, ctx) do
      {:ok, %{implementation: %{id: id}}} ->
        UploadEvents.create_info(ctx.job_id, %{
          type: "created",
          sheet: params["_sheet"],
          row_number: params["_row_number"],
          details: %{
            id: id,
            implementation_key: params["implementation_key"]
          }
        })

        {:created, id}

      {:error, :invalid_rule, rule_name} ->
        UploadEvents.create_error(ctx.job_id, %{
          type: "invalid_associated_rule",
          sheet: params["_sheet"],
          row_number: params["_row_number"],
          details: %{
            rule_name: rule_name
          }
        })

        :error

      {:error, :implementation, %{errors: errors}, _} ->
        UploadEvents.create_error(ctx.job_id, %{
          type: "implementation_creation_error",
          sheet: params["_sheet"],
          row_number: params["_row_number"],
          details: errors
        })

        :error

      error ->
        Logger.error("unexpected error: #{inspect(error)}")
        :error
    end
  end

  defp write_implementation([implementation], params, ctx) do
    df_content =
      implementation
      |> Map.get(:df_content)
      |> Map.merge(params["df_content"])

    params = Map.put(params, "df_content", df_content)

    case Implementations.maybe_update_implementation(
           implementation,
           params,
           ctx.claims,
           true
         ) do
      {:ok, %{error: :implementation_unchanged}} ->
        UploadEvents.create_info(ctx.job_id, %{
          type: "unchanged",
          sheet: params["_sheet"],
          row_number: params["_row_number"],
          details: %{
            id: implementation.id,
            implementation_key: params["implementation_key"]
          }
        })

        :unchanged

      {:ok, %{implementation: %{id: id}, changes: changes}} ->
        UploadEvents.create_info(ctx.job_id, %{
          type: "updated",
          sheet: params["_sheet"],
          row_number: params["_row_number"],
          details: %{
            id: implementation.id,
            implementation_key: params["implementation_key"],
            changes: changes
          }
        })

        {:updated, id}

      {:error, _, %{errors: errors}, _} ->
        UploadEvents.create_error(ctx.job_id, %{
          type: "implementation_creation_error",
          sheet: params["_sheet"],
          row_number: params["_row_number"],
          details: errors
        })

        :error

      {:error, {_, :deprecated}} ->
        UploadEvents.create_info(ctx.job_id, %{
          type: "unchanged",
          sheet: params["_sheet"],
          row_number: params["_row_number"],
          details: %{
            id: implementation.id,
            implementation_key: params["implementation_key"]
          }
        })

        :unchanged

      error ->
        Logger.error("unexpected error: #{inspect(error)}")
        :error
    end
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
