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
    "type" => "",
    "type_params" => %{}
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
    results
  end

  defp create_rules(rules, claims) do
    rules
    |> Enum.reduce(%{ids: [], errors: []}, fn %{"name" => rule_name} = rule, acc ->
      domain_id = get_domain_id(rule)
      rule_enriched = enrich_rule(rule, domain_id)

      case Rules.create_rule(rule_enriched, claims, true) do
        {:ok, %{rule: %{id: ids}}} ->
          Map.put(acc, :ids, [ids | acc.ids])

        {:error, _, changeset, _} = fail ->
          error = Changeset.traverse_errors(changeset, &ErrorHelpers.translate_error/1)

          Map.put(
            acc,
            :errors,
            [%{rule_name: rule_name, message: error} | acc.errors]
          )
      end
    end)
    |> Map.update!(:ids, &Enum.reverse(&1))
    |> Map.update!(:errors, &Enum.reverse(&1))
  end

  defp enrich_rule(rule, domain_id) do
    df_name = Map.get(rule, "template")

    rule
    |> Enum.reduce(%{"df_content" => %{}}, fn {head, value}, acc ->
      if Enum.member?(@required_headers ++ @optional_headers, head) do
        Map.put(acc, head, value)
      else
        df_content = Map.put(acc["df_content"], head, value)
        Map.put(acc, "df_content", df_content)
      end
    end)
    |> convert_description()
    |> Map.put("domain_id", domain_id)
    |> Map.put("df_name", df_name)
    |> Map.put("type", df_name)
    |> Map.delete("template")
    |> Map.delete("domain_external_id")
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

  defp convert_description(rule) do
    Map.put(rule, "description", %{})
  end

  defp get_domain_id(%{"domain_external_id" => domain_external_id}) do
    case DomainCache.external_id_to_id(domain_external_id) do
      {:ok, domain_id} -> domain_id
      _ -> nil
    end
  end
end
