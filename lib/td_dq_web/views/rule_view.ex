defmodule TdDqWeb.RuleView do
  use TdDqWeb, :view
  use TdHypermedia, :view
  alias TdDqWeb.RuleView
  alias TdDqWeb.RuleImplementationView
  alias TdPerms.BusinessConceptCache

  def render("index.json", %{hypermedia: hypermedia, rules: rules}) do
    render_many_hypermedia(rules, hypermedia, RuleView, "rule.json")
  end

  def render("index.json", %{rules: rules}) do
    %{data: render_many(rules, RuleView, "rule.json")}
  end

  def render("show.json", %{rule: rule}) do
    %{data: render_one(rule, RuleView, "rule.json")}
  end

  def render("rule.json", %{rule: rule}) do
    %{id: rule.id,
      business_concept_id: rule.business_concept_id,
      name: rule.name,
      description: rule.description,
      weight: rule.weight,
      priority: rule.priority,
      population: rule.population,
      goal: rule.goal,
      minimum: rule.minimum,
      status: rule.status,
      version: rule.version,
      updated_by: rule.updated_by,
      inserted_at: rule.inserted_at,
      updated_at: rule.updated_at,
      principle: rule.principle,
      type: rule.type,
      type_params: rule.type_params,
      current_business_concept_version: %{
        name: BusinessConceptCache.get_name(rule.business_concept_id),
        id: BusinessConceptCache.get_business_concept_version_id(rule.business_concept_id)
      }
    }
    |> add_rule_implementations(rule)
  end

  defp add_rule_implementations(rule, qc) do
    case Ecto.assoc_loaded?(qc.rule_implementations) do
      true ->
        rule_implementations_array = Enum.map(qc.rule_implementations, fn(rule_implemenetation) ->
          RuleImplementationView.render("rule_implementation.json", %{rule_implemenetation: rule_implemenetation})
        end)
        Map.put(rule, :rule_implementations, rule_implementations_array)
      _ ->
        rule
    end
  end
end
