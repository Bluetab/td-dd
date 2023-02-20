defmodule TdDd.DataStructures.DataStructureVersions do
  @moduledoc """
  The DataStructureVersion specific context.
  """
  import Bodyguard, only: [permit?: 4]

  alias TdCache.TemplateCache
  alias TdDd.DataStructures
  alias TdDd.DataStructures.Tags

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

  def enriched_data_structure_version(claims, data_structure_id, version) do
    data_structure_id
    |> DataStructures.get_data_structure!()
    |> enrich_opts(claims)
    |> get_data_structure_version(data_structure_id, version)
    |> with_permissions(claims)
  end

  def enriched_data_structure_version(claims, data_structure_version_id) do
    data_structure_version_id
    |> DataStructures.get_data_structure_version!()
    |> Map.get(:data_structure)
    |> enrich_opts(claims)
    |> get_data_structure_version(data_structure_version_id)
    |> with_permissions(claims)
  end

  defp enrich_opts(data_structure, %{user_id: user_id} = claims) do
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

  defp with_permissions(nil, _claims), do: :not_found

  defp with_permissions(%{data_structure: data_structure} = dsv, claims) do
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

      [
        data_structure_version: dsv,
        tags: tags,
        user_permissions: user_permissions,
        actions: actions(claims, dsv)
      ]
    else
      :forbidden
    end
  end

  defp actions(claims, %{data_structure: data_structure} = _dsv) do
    if permit?(DataStructures, :link_data_structure, claims, data_structure) do
      %{create_link: true}
    end
  end

  defp can_request_grant?(claims, data_structure) do
    {:ok, templates} = TemplateCache.list_by_scope("gr")

    permit?(DataStructures, :create_grant_request, claims, data_structure) and
      not Enum.empty?(templates)
  end

  defp get_data_structure_version(opts, data_structure_version_id) do
    DataStructures.get_data_structure_version!(data_structure_version_id, opts)
  end

  defp get_data_structure_version(opts, data_structure_id, "latest") do
    DataStructures.get_latest_version(data_structure_id, opts)
  end

  defp get_data_structure_version(opts, data_structure_id, version) do
    DataStructures.get_data_structure_version!(data_structure_id, version, opts)
  end
end
