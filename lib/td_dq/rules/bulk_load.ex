defmodule TdDq.Rules.BulkLoad do
  @moduledoc """
  Bulk Load Rules
  """

  alias Ecto.Changeset
  alias TdCache.DomainCache
  alias TdDdWeb.ErrorHelpers
  alias TdDq.Cache.RuleLoader
  alias TdDq.Rules

  @required_headers [
    "name",
    "domain_external_id"
  ]

  @optional_headers [
    "template",
    "description"
  ]

  @default_rule %{
    "version" => 1,
    "active" => false,
    "activeSelection" => false,
    "business_concept_id" => nil,
    "type" => ""
  }

  require Logger

  def required_headers, do: @required_headers

  def bulk_load(rules, claims) do
    Logger.info("Loading Rules...")

    Timer.time(
      fn -> do_bulk_load(rules, claims) end,
      fn millis, _ -> Logger.info("Rules loaded in #{millis}ms") end
    )
  end

  defp do_bulk_load(rules, claims) do
    %{ids: ids} = results = create_rules(rules, claims)
    RuleLoader.refresh(ids)
    {:ok, results}
  end

  defp create_rules(rules, claims) do
    rules
    |> Enum.reduce(%{ids: [], errors: []}, fn %{"name" => rule_name} = rule, acc ->
      enriched_rule = enrich_rule(rule)

      case Rules.create_rule(enriched_rule, claims, true) do
        {:ok, %{rule: %{id: id}}} ->
          %{acc | ids: [id | acc.ids]}

        {:error, _, changeset, _} ->
          error = Changeset.traverse_errors(changeset, &ErrorHelpers.translate_error/1)

          %{acc | errors: [%{rule_name: rule_name, message: error} | acc.errors]}
      end
    end)
    |> Map.update!(:ids, &Enum.reverse(&1))
    |> Map.update!(:errors, &Enum.reverse(&1))
  end

  defp enrich_rule(rule) do
    rule
    |> Enum.reduce(%{"df_content" => %{}}, fn {head, value}, acc ->
      if Enum.member?(@required_headers ++ @optional_headers, head) do
        Map.put(acc, head, value)
      else
        df_content = Map.put(acc["df_content"], head, value)
        Map.put(acc, "df_content", df_content)
      end
    end)
    |> ensure_template()
    |> convert_description()
    |> maybe_put_domain_id(rule)
    |> Map.merge(@default_rule)
  end

  defp convert_description(%{"description" => description} = rule) do
    description = %{
      document: %{
        nodes: [
          %{
            object: "block",
            type: "paragraph",
            nodes: [%{object: "text", leaves: [%{text: description}]}]
          }
        ]
      }
    }

    Map.put(rule, "description", description)
  end

  defp convert_description(rule), do: Map.put(rule, "description", %{})

  defp maybe_put_domain_id(params, %{"domain_external_id" => domain_external_id}) do
    case DomainCache.external_id_to_id(domain_external_id) do
      {:ok, domain_id} -> Map.put(params, "domain_id", domain_id)
      _ -> params
    end
  end

  defp ensure_template(%{"df_content" => df_content} = rule) do
    if Enum.empty?(df_content) or
         (!Enum.empty?(df_content) && Map.has_key?(rule, "template")) do
      rule
      |> Map.put("df_name", rule["template"])
      |> Map.delete("template")
    else
      rule
    end
  end
end
