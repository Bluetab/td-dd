defmodule TdDdWeb.DataStructureFilterView do
  use TdDdWeb, :view

  def render("show.json", %{filters: filters}) do
    %{data: filters}
  end
end
