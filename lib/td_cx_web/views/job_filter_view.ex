defmodule TdCxWeb.JobFilterView do
  use TdCxWeb, :view

  def render("show.json", %{filters: filters}) do
    %{data: filters}
  end
end
