defmodule TdDqWeb.SearchView do
  use TdDqWeb, :view

  alias TdDqWeb.ImplementationView
  alias TdDqWeb.RuleView

  def render("search.json", %{} = assigns) do
    assigns
    |> Enum.reduce(%{}, fn
      {:actions, actions}, acc ->
        Map.put(acc, :_actions, actions)

      {:filters, filters}, acc ->
        Map.put(acc, :filters, filters)

      {:user_permissions, user_permissions}, acc ->
        Map.put(acc, :user_permissions, user_permissions)

      {:rules, rules}, acc ->
        data = render_many(rules, RuleView, "rule.json", %{lang: Map.get(assigns, :locale)})
        Map.put(acc, :data, data)

      {:implementations, implementations}, acc ->
        data =
          render_many(implementations, ImplementationView, "implementation.json", %{
            lang: Map.get(assigns, :locale)
          })

        Map.put(acc, :data, data)

      {:scroll_id, scroll_id}, acc ->
        Map.put(acc, :scroll_id, scroll_id)

      _, acc ->
        acc
    end)
  end
end
