defmodule TdDqWeb.RuleView do
  use TdDqWeb, :view

  alias TdCache.ConceptCache
  alias TdDfLib.Content
  alias TdDq.Rules
  alias TdDqWeb.RuleView

  def render("index.json", %{actions: actions} = assigns) do
    "index.json"
    |> render(Map.delete(assigns, :actions))
    |> Map.put(:_actions, actions)
  end

  def render("index.json", %{managable_domain_ids: domain_ids} = assigns) do
    "index.json"
    |> render(Map.delete(assigns, :managable_domain_ids))
    |> Map.put(:_managable_domain_ids, domain_ids)
  end

  def render("index.json", %{user_permissions: user_permissions} = assigns) do
    "index.json"
    |> render(Map.delete(assigns, :user_permissions))
    |> Map.put(:user_permissions, user_permissions)
  end

  def render("index.json", %{rules: rules}) do
    %{data: render_many(rules, RuleView, "rule.json")}
  end

  def render("show.json", %{rule: rule, user_permissions: user_permissions} = assigns) do
    %{
      user_permissions: user_permissions,
      data: render_one(rule, RuleView, "rule.json", %{lang: Map.get(assigns, :locale)})
    }
  end

  def render("show.json", %{rule: rule}) do
    %{data: render_one(rule, RuleView, "rule.json")}
  end

  def render("rule.json", %{rule: rule} = assigns) do
    lang = Map.get(assigns, :lang)

    rule
    |> Map.take([
      :active,
      :business_concept_id,
      :business_concept_name,
      :deleted_at,
      :description,
      :domain_id,
      :domain,
      :execution_result_info,
      :id,
      :inserted_at,
      :name,
      :updated_at,
      :updated_by,
      :version
    ])
    |> add_current_version(rule, lang)
    |> add_system_values(rule)
    |> add_dynamic_content(rule)
    |> Content.legacy_content_support(:df_content)
  end

  def render("embedded.json", %{rule: rule}) do
    Map.take(rule, [:id, :name])
  end

  defp add_current_version(rule, %{business_concept_id: business_concept_id}, lang) do
    case ConceptCache.get(business_concept_id, lang: lang, refresh: true) do
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
