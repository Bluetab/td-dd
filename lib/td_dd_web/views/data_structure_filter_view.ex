defmodule TdDdWeb.DataStructureFilterView do
  use TdDdWeb, :view

  def render("show.json", %{filters: filters}) do
    %{data: filters}
  end

  def render("bucket_paths.json", %{bucket_paths: bucket_paths}), do: bucket_paths
end
