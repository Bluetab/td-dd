defmodule TdDdWeb.DataStructureVersionController do
  use TdDdWeb, :controller
  use TdHypermedia, :controller
  use PhoenixSwagger

  import Canada, only: [can?: 2]

  alias Ecto
  alias TdCache.TaxonomyCache
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
    :external_id,
    :parents,
    :children,
    :siblings,
    :data_fields,
    :data_field_degree,
    :data_field_links,
    :versions,
    :system,
    :ancestry,
    :links,
    :profile,
    :degree,
    :relations
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
    user = conn.assigns[:current_user]

    case DataStructures.get_data_structure!(data_structure_id) do
      %DataStructure{} = data_structure ->
        options = filter(user, data_structure)

        dsv =
          data_structure_id
          |> get_data_structure_version(version, options)
          |> with_domain()

        render_with_permissions(conn, user, dsv)

      %Ecto.NoResultsError{} ->
        render_error(conn, :not_found)
    end
  end

  def show(conn, %{"id" => data_structure_version_id}) do
    user = conn.assigns[:current_user]

    case DataStructures.get_data_structure_version!(data_structure_version_id) do
      %DataStructureVersion{data_structure: data_structure} ->
        options = filter(user, data_structure)

        dsv =
          data_structure_version_id
          |> get_data_structure_version(options)
          |> with_domain()

        render_with_permissions(conn, user, dsv)

      %Ecto.NoResultsError{} ->
        render_error(conn, :not_found)
    end
  end

  defp filter(user, data_structure) do
    Enum.filter(@enrich_attrs, &filter(user, data_structure, &1))
  end

  defp filter(user, data_structure, :profile) do
    can?(user, view_data_structures_profile(data_structure))
  end

  defp filter(_user, _data_structure, _attr), do: true

  defp with_domain(nil), do: nil

  defp with_domain(%{data_structure: data_structure} = dsv) do
    domain_name =
      data_structure
      |> Map.get(:domain_id)
      |> TaxonomyCache.get_name()

    data_structure = Map.put(data_structure, :domain, domain_name)
    Map.put(dsv, :data_structure, data_structure)
  end

  defp render_with_permissions(conn, _user, nil) do
    render_error(conn, :not_found)
  end

  defp render_with_permissions(conn, user, %{data_structure: data_structure} = dsv) do
    if can?(user, view_data_structure(data_structure)) do
      user_permissions = %{
        update: can?(user, update_data_structure(data_structure)),
        confidential: can?(user, manage_confidential_structures(data_structure)),
        view_profiling_permission: can?(user, view_data_structures_profile(data_structure))
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
end
