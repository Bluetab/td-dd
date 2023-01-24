defmodule TdDdWeb.ReferenceDataView do
  use TdDdWeb, :view

  def render("index.json", %{datasets: datasets}) do
    data =
      Enum.map(
        datasets,
        &Map.take(&1, [:id, :name, :headers, :row_count, :inserted_at, :updated_at])
      )

    %{data: data}
  end

  def render("show.json", %{dataset: dataset}) do
    data = Map.take(dataset, [:id, :name, :headers, :rows, :row_count, :domain_ids, :inserted_at, :updated_at])
    %{data: data}
  end
end
