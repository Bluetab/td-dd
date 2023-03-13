defmodule TdDqWeb.RemediationView do
  use TdDqWeb, :view

  alias TdCache.TemplateCache
  alias TdDfLib.Format

  def render("show.json", %{actions: actions} = assigns) do
    "show.json"
    |> render(Map.delete(assigns, :actions))
    |> Map.put(:_actions, actions)
  end

  def render("show.json", %{remediation: remediation} = assigns) do
    %{
      data: render_one(remediation, __MODULE__, "remediation.json", Map.delete(assigns, :source))
    }
  end

  def render("remediation.json", %{remediation: remediation}) do
    add_cached_content(%{id: remediation.id}, remediation)
  end

  defp add_cached_content(remediation_json, %{df_name: df_name} = remediation) do
    {:ok, template} = TemplateCache.get_by_name(df_name)

    content =
      remediation
      |> Map.get(:df_content)
      |> Format.enrich_content_values(template, [:system, :hierarchy])

    %{
      df_name: df_name,
      df_content: content
    }
    |> Map.merge(remediation_json)
  end
end
