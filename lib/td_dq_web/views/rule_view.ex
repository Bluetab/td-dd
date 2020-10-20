defmodule TdDqWeb.RuleView do
  use TdDqWeb, :view
  use TdHypermedia, :view

  alias TdCache.ConceptCache
  alias TdDq.Rules
  alias TdDqWeb.RuleView

  def render("index.json", %{hypermedia: hypermedia}) do
    render_many_hypermedia(hypermedia, RuleView, "rule.json")
  end

  def render("index.json", %{rules: rules, user_permissions: user_permissions}) do
    %{
      user_permissions: user_permissions,
      data: render_many(rules, RuleView, "rule.json")
    }
  end

  def render("show.json", %{
        hypermedia: hypermedia,
        rule: rule,
        user_permissions: user_permissions
      }) do
    Map.merge(
      %{"user_permissions" => user_permissions},
      render_one_hypermedia(rule, hypermedia, RuleView, "rule.json")
    )
  end

  def render("show.json", %{hypermedia: hypermedia, rule: rule}) do
    render_one_hypermedia(rule, hypermedia, RuleView, "rule.json")
  end

  def render("show.json", %{rule: rule, user_permissions: user_permissions}) do
    %{
      user_permissions: user_permissions,
      data: render_one(rule, RuleView, "rule.json")
    }
  end

  def render("show.json", %{rule: rule}) do
    %{data: render_one(rule, RuleView, "rule.json")}
  end

  def render("rule.json", %{rule: rule}) do
    %{
      id: rule.id,
      business_concept_id: rule.business_concept_id,
      name: rule.name,
      deleted_at: rule.deleted_at,
      description: rule.description,
      goal: rule.goal,
      minimum: rule.minimum,
      active: rule.active,
      version: rule.version,
      updated_by: rule.updated_by,
      inserted_at: rule.inserted_at,
      updated_at: rule.updated_at,
      execution_result_info: Map.get(rule, :execution_result_info),
      result_type: Map.get(rule, :result_type)
    }
    |> add_current_version(rule)
    |> add_system_values(rule)
    |> add_dynamic_content(rule)
  end

  defp add_current_version(rule, %{business_concept_id: business_concept_id}) do
    case ConceptCache.get(business_concept_id) do
      {:ok, %{business_concept_version_id: id} = concept} ->
        current_version =
          concept
          |> Map.take([:name, :content])
          |> Map.put(:id, id)

        Map.put(rule, :current_business_concept_version, current_version)

      _ ->
        rule
    end
  end

  defp add_system_values(rule_mapping, rule) do
    case Map.get(rule, :system_values) do
      nil -> rule_mapping
      value -> rule_mapping |> Map.put(:system_values, value)
    end
  end

  defp add_dynamic_content(json, rule) do
    df_name = Map.get(rule, :df_name)

    content =
      rule
      |> Map.get(:df_content)
      |> Rules.get_cached_content(df_name)

    %{
      df_name: df_name,
      df_content: content
    }
    |> Map.merge(json)
  end
end
