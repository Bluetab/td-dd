defmodule TdDdWeb.DataStructureVersionController do
  use TdDdWeb, :controller
  use TdHypermedia, :controller
  use PhoenixSwagger

  import Canada, only: [can?: 2]

  alias Ecto
  alias TdCache.TaxonomyCache
  alias TdDd.DataStructures
  alias TdDdWeb.SwaggerDefinitions

  require Logger

  action_fallback(TdDdWeb.FallbackController)

  def swagger_definitions do
    SwaggerDefinitions.data_structure_version_swagger_definitions()
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
    :profile,
    :data_structure_lineage_id
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

    dsv = get_data_structure_version(data_structure_id, version)
    options = filter(user, dsv)
    dsv = DataStructures.enrich(dsv, options)
    render_with_permissions(conn, user, with_domain(dsv))
  end

  def show(conn, %{"id" => data_structure_version_id}) do
    user = conn.assigns[:current_user]

    dsv = get_data_structure_version(data_structure_version_id)
    options = filter(user, dsv)
    dsv = DataStructures.enrich(dsv, options)

    render_with_permissions(conn, user, with_domain(dsv))
  end

  defp filter(_user, nil), do: nil

  defp filter(user, %{data_structure: data_structure}) do
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
    with true <- can?(user, view_data_structure(data_structure)) do
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
      false -> render_error(conn, :forbidden)
      _error -> render_error(conn, :unprocessable_entity)
    end
  end

  defp get_data_structure_version(data_structure_version_id) do
    DataStructures.get_data_structure_version!(data_structure_version_id, nil)
  end

  defp get_data_structure_version(data_structure_id, "latest") do
    DataStructures.get_latest_version(data_structure_id, nil)
  end

  defp get_data_structure_version(data_structure_id, version) do
    DataStructures.get_data_structure_version!(data_structure_id, version, nil)
  end
end
