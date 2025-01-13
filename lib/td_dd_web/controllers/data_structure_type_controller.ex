defmodule TdDdWeb.DataStructureTypeController do
  use TdDdWeb, :controller

  alias TdDd.DataStructures.DataStructureTypes

  action_fallback(TdDdWeb.FallbackController)

  def index(conn, _params) do
    claims = conn.assigns[:current_resource]

    with :ok <- Bodyguard.permit(DataStructureTypes, :index, claims) do
      data_structure_types =
        DataStructureTypes.list_data_structure_types(preload: :metadata_fields)

      render(conn, "index.json", data_structure_types: data_structure_types)
    end
  end

  def show(conn, %{"id" => id}) do
    claims = conn.assigns[:current_resource]

    with data_structure_type <- DataStructureTypes.get!(id),
         :ok <- Bodyguard.permit(DataStructureTypes, :view, claims, data_structure_type) do
      render(conn, "show.json", data_structure_type: data_structure_type)
    end
  end

  def update(conn, %{"id" => id, "data_structure_type" => params}) do
    claims = conn.assigns[:current_resource]
    data_structure_type = DataStructureTypes.get!(id)

    with :ok <- Bodyguard.permit(DataStructureTypes, :update, claims, data_structure_type),
         {:ok, data_structure_type} <-
           DataStructureTypes.update_data_structure_type(data_structure_type, params) do
      render(conn, "show.json", data_structure_type: data_structure_type)
    end
  end
end
