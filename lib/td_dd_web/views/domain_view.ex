defmodule TdDdWeb.DomainView do
  use TdDdWeb, :view

  def render("embedded.json", %{domain: domain}) do
    Map.take(domain, [:id, :external_id, :name])
  end
end
