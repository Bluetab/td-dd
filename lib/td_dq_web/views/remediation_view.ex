defmodule TdDqWeb.RemediationView do
  use TdDqWeb, :view

  def render("show.json", %{remediation: remediation} = assigns) do
    %{data: render_one(remediation, __MODULE__, "remediation.json", Map.delete(assigns, :source))}
  end

  def render("remediation.json", %{remediation: remediation} = assigns) do
    #config = Map.get(source, :config)

    %{
      id: remediation.id,
      #rule: Map.take(remediation.rule, [:id, :name]),
      df_name: remediation.df_name,
      df_content: remediation.df_content
    }
  end

end
