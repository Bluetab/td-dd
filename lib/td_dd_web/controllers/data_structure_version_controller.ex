defmodule TdDdWeb.DataStructureVersionController do
  use TdDdWeb, :controller
  use PhoenixSwagger

  import Bodyguard, only: [permit?: 4]

  alias Ecto
  alias TdCache.TemplateCache
  alias TdDd.DataStructures
  alias TdDd.DataStructures.Tags
  alias TdDdWeb.SwaggerDefinitions

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
    :data_structure_link_count,
    :with_protected_metadata,
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
    :implementation_count,
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
      :profile ->
        permit?(DataStructures, :view_data_structures_profile, claims, data_structure)

      :with_confidential ->
        permit?(DataStructures, :manage_confidential_structures, claims, data_structure)

      :grants ->
        permit?(DataStructures, :view_grants, claims, data_structure)

      :with_protected_metadata ->
        permit?(DataStructures, :view_protected_metadata, claims, data_structure)

      _ ->
        true
    end) ++ [user_id: user_id]
  end

  defp render_with_permissions(conn, _claims, nil) do
    render_error(conn, :not_found)
  end

  defp render_with_permissions(conn, claims, %{data_structure: data_structure} = dsv) do
    if permit?(DataStructures, :view_data_structure, claims, data_structure) do
      tags = Tags.tags(dsv)
      dsv = DataStructures.profile_source(dsv)

      user_permissions = %{
        update: permit?(DataStructures, :update_data_structure, claims, data_structure),
        confidential:
          permit?(DataStructures, :manage_confidential_structures, claims, data_structure),
        update_domain: permit?(DataStructures, :manage_structures_domain, claims, data_structure),
        view_profiling_permission:
          permit?(DataStructures, :view_data_structures_profile, claims, data_structure),
        profile_permission: permit?(TdDd.Profiles, :profile, claims, dsv),
        request_grant: can_request_grant?(claims, data_structure),
        update_grant_removal:
          permit?(DataStructures, :request_grant_removal, claims, data_structure),
        create_foreign_grant_request:
          permit?(DataStructures, :create_foreign_grant_request, claims, data_structure)
      }

      render(conn, "show.json",
        data_structure_version: dsv,
        tags: tags,
        user_permissions: user_permissions,
        actions: actions(conn, claims, dsv)
      )
    else
      render_error(conn, :forbidden)
    end
  end

  defp actions(conn, claims, %{data_structure: data_structure} = _dsv) do
    [:link_data_structure, :link_structure_to_structure]
    |> Enum.filter(&Bodyguard.permit?(DataStructures, &1, claims, data_structure))
    |> Enum.reduce(
      %{},
      fn
        :link_data_structure, acc ->
          Map.put(acc, :create_link, %{})

        :link_structure_to_structure, acc ->
          Map.put(
            acc,
            :link_structure_to_structure,
            %{
              href: Routes.data_structure_link_path(conn, :create),
              method: "POST"
            }
          )
      end
    )
  end

  defp can_request_grant?(claims, data_structure) do
    {:ok, templates} = TemplateCache.list_by_scope("gr")

    permit?(DataStructures, :create_grant_request, claims, data_structure) and
      not Enum.empty?(templates)
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
