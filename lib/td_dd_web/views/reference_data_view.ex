defmodule TdDdWeb.ReferenceDataView do
  use TdDdWeb, :view

  def render("index.json", %{datasets: datasets}) do
    data =
      Enum.map(datasets, fn %{rows: rows} = dataset ->
        dataset
        |> Map.take([:id, :name, :headers, :inserted_at, :updated_at])
        |> Map.put(:row_count, length(rows))
      end)

    %{data: data}
  end

  def render("show.json", %{dataset: dataset}) do
    data = Map.take(dataset, [:id, :name, :headers, :rows, :inserted_at, :updated_at])
    %{data: data}
  end
end
