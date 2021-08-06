defmodule TdDdWeb.UnitDomainView do
    use TdDdWeb, :view
    alias TdDdWeb.UnitDomainView
  
    def render("index.json", %{unit_domains: unit_domains}) do
      %{data: render_many(unit_domains, UnitDomainView, "unit_domain.json")}
    end
  
    def render("unit_domain.json", %{unit_domain: unit_domain}) do
      %{
        id: unit_domain.id,
        name: unit_domain.name,
        external_id: unit_domain.external_id,
        parent_ids: unit_domain.parent_ids
      }
    end  
  end
  