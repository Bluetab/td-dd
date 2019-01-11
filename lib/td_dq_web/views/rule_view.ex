defmodule TdDqWeb.RuleView do
  use TdDqWeb, :view
  use TdHypermedia, :view
  alias TdDqWeb.RuleView
  alias TdPerms.BusinessConceptCache

  def render("index.json", %{hypermedia: hypermedia, rules: rules}) do
    render_many_hypermedia(rules, hypermedia, RuleView, "rule.json")
  end

  def render("index.json", %{rules: rules, user_permissions: user_permissions}) do
    %{
      user_permissions: user_permissions,
      data: render_many(rules, RuleView, "rule.json")
    }
  end

  def render("show.json", %{hypermedia: hypermedia, rule: rule}) do
    render_one_hypermedia(rule, hypermedia, RuleView, "rule.json")
  end

  def render("show.json", %{rule: rule}) do
    %{data: render_one(rule, RuleView, "rule.json")}
  end

  def render("rule.json", %{rule: rule}) do
    %{id: rule.id,
      business_concept_id: rule.business_concept_id,
      name: rule.name,
      deleted_at: rule.deleted_at,
      description: rule.description,
      weight: rule.weight,
      priority: rule.priority,
      population: rule.population,
      goal: rule.goal,
      minimum: rule.minimum,
      active: rule.active,
      version: rule.version,
      updated_by: rule.updated_by,
      inserted_at: rule.inserted_at,
      updated_at: rule.updated_at,
      principle: rule.principle,
      rule_type_id: rule.rule_type_id,
      type_params: rule.type_params,
      tag: retrieve_tag(rule),
      current_business_concept_version: %{
        name: BusinessConceptCache.get_name(rule.business_concept_id),
        id: BusinessConceptCache.get_business_concept_version_id(rule.business_concept_id)
      }
    }
    |> add_rule_type(rule)
  end

  defp retrieve_tag(rule) do
    case Map.get(rule, :tag, %{}) do
      nil -> %{}
      value -> value
    end
  end

  defp add_rule_type(rule_mapping, rule) do
    case Ecto.assoc_loaded?(rule.rule_type) do
      true ->
        rule_type_mapping = %{
          id: rule.rule_type.id,
          name: rule.rule_type.name,
          params: rule.rule_type.params
        }
        Map.put(rule_mapping, :rule_type, rule_type_mapping)

      _ ->
        rule_mapping
    end
  end

end
