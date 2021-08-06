defmodule TdDdWeb.UnitDomainView do
  use TdDdWeb, :view
  alias TdDdWeb.UnitDomainView

  def render("index.json", %{unit_domains: unit_domains}) do
    %{data: render_many(unit_domains, UnitDomainView, "unit_domain.json")}
  end

  def render("unit_domain.json", %{unit_domain: unit_domain}) do
    Map.take(unit_domain, [:id, :name, :external_id, :parent_ids, :unit])
  end
end
