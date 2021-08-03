defmodule TdDdWeb.DataStructureVersionController do
  use TdDdWeb, :controller
  use TdHypermedia, :controller
  use PhoenixSwagger

  import Canada, only: [can?: 2]

  alias Ecto
  alias TdDd.DataStructures
  alias TdDd.DataStructures.DataStructure
  alias TdDd.DataStructures.DataStructureVersion
  alias TdDdWeb.SwaggerDefinitions

  require Logger

  action_fallback(TdDdWeb.FallbackController)

  def swagger_definitions do
    SwaggerDefinitions.data_structure_version_swagger_definitions()
  end

  @enrich_attrs [
    :children,
    :classifications,
    :data_field_degree,
    :data_field_links,
    :data_fields,
    :data_structure_type,
    :degree,
    :domain,
    :external_id,
    :links,
    :metadata_versions,
    :parents,
    :profile,
    :relation_links,
    :relations,
    :siblings,
    :source,
    :system,
    :tags,
    :versions,
    :with_confidential,
    :grant
  ]

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
    claims = conn.assigns[:current_resource]

    data_structure = DataStructures.get_data_structure!(data_structure_id)
    options = filter(claims, data_structure) ++ [user_id: claims.user_id]
    dsv = get_data_structure_version(data_structure_id, version, options)
    render_with_permissions(conn, claims, dsv)
  end

  def show(conn, %{"id" => data_structure_version_id}) do
    claims = conn.assigns[:current_resource]
    dsv = DataStructures.get_data_structure_version!(data_structure_version_id)
    options = filter(claims, dsv.data_structure) ++ [user_id: claims.user_id]
    dsv = get_data_structure_version(data_structure_version_id, options)
    render_with_permissions(conn, claims, dsv)
  end

  defp filter(claims, data_structure) do
    Enum.filter(@enrich_attrs, &filter(claims, data_structure, &1))
  end

  defp filter(claims, data_structure, :profile) do
    can?(claims, view_data_structures_profile(data_structure))
  end

  defp filter(claims, data_structure, :with_confidential) do
    can?(claims, manage_confidential_structures(data_structure))
  end

  defp filter(_claims, _data_structure, _attr), do: true

  defp render_with_permissions(conn, _claims, nil) do
    render_error(conn, :not_found)
  end

  defp render_with_permissions(conn, claims, %{data_structure: data_structure} = dsv) do
    if can?(claims, view_data_structure(data_structure)) do
      dsv = DataStructures.profile_source(dsv)

      user_permissions = %{
        update: can?(claims, update_data_structure(data_structure)),
        confidential: can?(claims, manage_confidential_structures(data_structure)),
        update_domain: can?(claims, manage_structures_domain(data_structure)),
        view_profiling_permission: can?(claims, view_data_structures_profile(data_structure)),
        profile_permission: can?(claims, profile(dsv)),
        manage_tags: can?(claims, link_data_structure_tag(data_structure))
      }

      render(conn, "show.json",
        data_structure_version: dsv,
        user_permissions: user_permissions,
        hypermedia: hypermedia("data_structure_version", conn, dsv)
      )
    else
      render_error(conn, :forbidden)
    end
  end

  defp get_data_structure_version(data_structure_version_id, options) do
    DataStructures.get_data_structure_version!(data_structure_version_id, options)
  end

  defp get_data_structure_version(data_structure_id, "latest", options) do
    DataStructures.get_latest_version(data_structure_id, options)
  end

  defp get_data_structure_version(data_structure_id, version, options) do
    DataStructures.get_data_structure_version!(data_structure_id, version, options)
  end

  swagger_path :delete do
    description("Logical Delete Data Structure")
    produces("application/json")

    parameters do
      id(:path, :integer, "Data Structure ID", required: true)
    end

    response(204, "No Content")
    response(400, "Client Error")
    response(403, "Forbidden")
    response(422, "Unprocessable Entity")
  end

  def delete(conn, %{"data_structure_id" => data_structure_id, "id" => _version}) do
    claims = conn.assigns[:current_resource]

    with %DataStructure{} = data_structure <-
           DataStructures.get_data_structure!(data_structure_id),
         {:can, true} <- {:can, can?(claims, delete_structure(data_structure))},
         %DataStructureVersion{} = data_structure_version <-
           DataStructures.get_latest_version(data_structure),
         {:ok, _} <-
           DataStructures.logical_delete_data_structure(
             data_structure_version,
             claims
           ) do
      send_resp(conn, :no_content, "")
    end
  end
end
