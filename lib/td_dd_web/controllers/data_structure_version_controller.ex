defmodule TdDdWeb.DataStructureVersionController do
  require Logger
  import Canada, only: [can?: 2]
  use TdDdWeb, :controller
  use PhoenixSwagger
  alias Ecto
  alias TdDd.DataStructures
  alias TdDdWeb.ErrorView
  alias TdDdWeb.SwaggerDefinitions

  action_fallback(TdDdWeb.FallbackController)

  def swagger_definitions do
    SwaggerDefinitions.data_structure_version_swagger_definitions()
  end

  swagger_path :show do
    description("Show Data Structure")
    produces("application/json")

    parameters do
      id(:path, :integer, "Data Structure ID", required: true)
      version(:path, :integer, "Version number", required: true)
    end

    response(200, "OK", Schema.ref(:DataStructureVersionResponse))
    response(400, "Client Error")
    response(403, "Unauthorized")
    response(422, "Unprocessable Entity")
  end

  def show(conn, %{"data_structure_id" => data_structure_id, "id" => version}) do
    user = conn.assigns[:current_user]

    dsv = get_data_structure_version(data_structure_id, version)

    with true <- can?(user, view_data_structure(dsv.data_structure)) do
      render(conn, "show.json", data_structure_version: dsv)
    else
      false ->
        conn
        |> put_status(:forbidden)
        |> render(ErrorView, :"403")

      _error ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(ErrorView, :"422")
    end
  end

  defp get_data_structure_version(data_structure_id, version) do
    dsv = DataStructures.get_data_structure_version!(data_structure_id, version)
    parents = DataStructures.get_parents(dsv, [deleted: false])
    siblings = DataStructures.get_siblings(dsv, [deleted: false])
    children = DataStructures.get_children(dsv, [deleted: false])
    fields = DataStructures.get_fields(dsv, [deleted: false])
    versions = DataStructures.get_versions(dsv)
    ancestry = DataStructures.get_ancestry(dsv)
    system = dsv.data_structure.system

    dsv
    |> Map.put(:parents, parents)
    |> Map.put(:children, children)
    |> Map.put(:siblings, siblings)
    |> Map.put(:data_fields, fields)
    |> Map.put(:versions, versions)
    |> Map.put(:system, system)
    |> Map.put(:ancestry, ancestry)
  end
end
