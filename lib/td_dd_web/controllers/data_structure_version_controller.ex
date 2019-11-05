defmodule TdDdWeb.DataStructureVersionController do
  use TdDdWeb, :controller
  use PhoenixSwagger

  import Canada, only: [can?: 2]

  alias Ecto
  alias TdDd.DataStructures
  alias TdDdWeb.SwaggerDefinitions

  require Logger

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
    response(403, "Forbidden")
    response(422, "Unprocessable Entity")
  end

  def show(conn, %{"data_structure_id" => data_structure_id, "id" => version}) do
    user = conn.assigns[:current_user]
    dsv = get_data_structure_version(data_structure_id, version)
    render_with_permissions(conn, user, dsv)
  end

  def show(conn, %{"id" => data_structure_version_id}) do
    user = conn.assigns[:current_user]
    dsv = get_data_structure_version(data_structure_version_id)
    render_with_permissions(conn, user, dsv)
  end

  swagger_path :profiling do
    description("Gets Profiling")
    produces("application/json")

    response(202, "Accepted")
  end

  def profiling(conn, _params) do
    # This method is only used to generate an action in the data structure hypermedia response
    send_resp(conn, :accepted, "")
  end

  swagger_path :confidential do
    description("Gets Confidential Structures")
    produces("application/json")

    response(202, "Accepted")
  end

  def manage_confidential_structures(conn, _params) do
    # This method is only used to generate an action in the data structure hypermedia response
    send_resp(conn, :accepted, "")
  end

  defp render_with_permissions(conn, _user, nil) do
    render_error(conn, :not_found)
  end

  defp render_with_permissions(conn, user, %{data_structure: data_structure} = dsv) do
    with true <- can?(user, view_data_structure(data_structure)) do
      conn
      |> put_hypermedia(["data_structure_versions", "data_structures"], data_structure_version: dsv)
      |> render("show.json")
    else
      false -> render_error(conn, :forbidden)
      _error -> render_error(conn, :unprocessable_entity)
    end
  end

  @enrich_attrs [
    :parents,
    :children,
    :siblings,
    :data_fields,
    :data_field_external_ids,
    :data_field_links,
    :versions,
    :system,
    :ancestry,
    :links,
    :profile
  ]

  defp get_data_structure_version(data_structure_version_id) do
    DataStructures.get_data_structure_version!(data_structure_version_id, @enrich_attrs)
  end

  defp get_data_structure_version(data_structure_id, "latest") do
    DataStructures.get_latest_version(data_structure_id, @enrich_attrs)
  end

  defp get_data_structure_version(data_structure_id, version) do
    DataStructures.get_data_structure_version!(data_structure_id, version, @enrich_attrs)
  end
end
