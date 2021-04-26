defmodule TdDdWeb.MetadataView do
  use TdDdWeb, :view

  def render("show.json", %{data_structure_version: dsv}) do
    %{
      data:
        dsv
        |> Map.take([
          :class,
          :data_structure_id,
          :deleted_at,
          :description,
          :group,
          :id,
          :metadata,
          :name,
          :type,
          :version
        ])
    }
  end
end
