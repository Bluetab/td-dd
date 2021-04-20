defmodule TdDqWeb.FilterView do
  use TdDqWeb, :view

  def render("show.json", %{filters: filters}) do
    %{data: filters}
  end
end
