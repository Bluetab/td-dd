defmodule TdDqWeb.RemediationView do
  use TdDqWeb, :view
  use TdHypermedia, :view

  def render("show.json", %{remediation: remediation, actions: actions} = assigns) do
    %{
      data: render_one(remediation, __MODULE__, "remediation.json", Map.delete(assigns, :source)),
      _actions: actions
    }
  end

  def render("remediation.json", %{remediation: remediation}) do
    %{
      id: remediation.id,
      df_name: remediation.df_name,
      df_content: remediation.df_content
    }
  end
end
