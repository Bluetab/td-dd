defmodule TdDdWeb.DataStructureVersionController do
  use TdDdWeb, :controller
  use TdHypermedia, :controller
  use PhoenixSwagger

  import Canada, only: [can?: 2]

  alias Ecto
  alias TdCache.TemplateCache
  alias TdDd.DataStructures
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
    :grant,
    :grants,
    :implementations,
    :published_note
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
    options = enrich_opts(claims, data_structure)
    dsv = get_data_structure_version(data_structure_id, version, options)
    render_with_permissions(conn, claims, dsv)
  end

  def show(conn, %{"id" => data_structure_version_id}) do
    claims = conn.assigns[:current_resource]
    dsv = DataStructures.get_data_structure_version!(data_structure_version_id)
    options = enrich_opts(claims, dsv.data_structure)
    dsv = get_data_structure_version(data_structure_version_id, options)
    render_with_permissions(conn, claims, dsv)
  end

  defp enrich_opts(%{user_id: user_id} = claims, data_structure) do
    Enum.filter(@enrich_attrs, fn
      :profile -> can?(claims, view_data_structures_profile(data_structure))
      :with_confidential -> can?(claims, manage_confidential_structures(data_structure))
      :grants -> can?(claims, view_grants(data_structure))
      _ -> true
    end) ++ [user_id: user_id]
  end

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
        request_grant: can_request_grant?(claims, data_structure),
        update_grant_removal: can_update_grant_removal?(claims, data_structure)
      }

      render(conn, "show.json",
        data_structure_version: dsv,
        user_permissions: user_permissions,
        actions: actions(claims, data_structure),
        hypermedia: hypermedia("data_structure_version", conn, dsv)
      )
    else
      render_error(conn, :forbidden)
    end
  end

  defp actions(claims, data_structure) do
    if can?(claims, link_data_structure_tag(data_structure)) do
      %{manage_tags: DataStructures.list_available_tags(data_structure)}
    else
      %{}
    end
  end

  defp can_request_grant?(claims, data_structure) do
    {:ok, templates} = TemplateCache.list_by_scope("gr")
    can?(claims, create_grant_request(data_structure)) and not Enum.empty?(templates)
  end

  defp can_update_grant_removal?(claims, data_structure) do
    can?(claims, update_grant_removal(data_structure))
  end

  defp get_data_structure_version(data_structure_version_id, opts) do
    DataStructures.get_data_structure_version!(data_structure_version_id, opts)
  end

  defp get_data_structure_version(data_structure_id, "latest", opts) do
    DataStructures.get_latest_version(data_structure_id, opts)
  end

  defp get_data_structure_version(data_structure_id, version, opts) do
    DataStructures.get_data_structure_version!(data_structure_id, version, opts)
  end
end
