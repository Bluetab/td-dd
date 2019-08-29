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

    render_with_permissions(conn, user, dsv)
  end

  def show(conn, %{"id" => data_structure_version_id}) do
    user = conn.assigns[:current_user]

    dsv = get_data_structure_version(data_structure_version_id)

    render_with_permissions(conn, user, dsv)
  end

  def render_with_permissions(conn, _user, nil) do
    conn
    |> put_status(:not_found)
    |> put_view(ErrorView)
    |> render("404.json")
  end

  def render_with_permissions(conn, user, %{data_structure: data_structure} = dsv) do
    with true <- can?(user, view_data_structure(data_structure)) do
      user_permissions = %{
        update: can?(user, update_data_structure(data_structure)),
        confidential: can?(user, manage_confidential_structures(data_structure)),
        view_profiling_permission: can?(user, view_data_structures_profile(data_structure))
      }

      render(conn, "show.json", data_structure_version: dsv, user_permissions: user_permissions)
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
    :links
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
