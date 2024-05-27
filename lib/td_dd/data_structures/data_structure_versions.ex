defmodule TdDd.DataStructures.DataStructureVersions do
  @moduledoc """
  The DataStructureVersion specific context.
  """
  import Bodyguard, only: [permit?: 4]

  alias TdCache.TemplateCache
  alias TdDd.DataStructures
  alias TdDd.DataStructures.Tags

  @controller_enrich_attrs [
    :data_fields,
    :data_field_degree,
    :data_field_links,
    :children,
    :parents,
    :data_structure_type,
    :siblings,
    :versions,
    :classifications,
    :implementation_count,
    :data_structure_link_count,
    :degree,
    :profile,
    :source,
    :system,
    :grant,
    :grants,
    :links,
    :relations,
    :relation_links,
    :tags,
    :metadata_versions,
    :published_note
  ]

  @base_enrich_attrs [
    :domain,
    :external_id,
    :with_confidential,
    :with_protected_metadata
  ]

  @protected DataStructures.protected()

  def enriched_data_structure_version(
        claims,
        data_structure_id,
        version,
        query_fields \\ nil
      ) do
    enriches = query_fields_to_enrich_opts(query_fields)

    data_structure_id
    |> DataStructures.get_data_structure!()
    |> enrich_opts(claims, enriches)
    |> get_data_structure_version(data_structure_id, version)
    |> add_data_fields()
    |> merge_metadata()
    |> with_permissions(claims)
  end

  def enriched_data_structure_version_by_id(
        claims,
        data_structure_version_id,
        query_fields \\ nil
      ) do
    enriches = query_fields_to_enrich_opts(query_fields)

    data_structure_version_id
    |> DataStructures.get_data_structure_version!()
    |> Map.get(:data_structure)
    |> enrich_opts(claims, enriches)
    |> get_data_structure_version(data_structure_version_id)
    |> with_permissions(claims)
  end

  def with_profile_attrs(dsv, %{} = profile) when profile !== %{} do
    profile =
      profile
      |> Map.take([
        :max,
        :min,
        :most_frequent,
        :null_count,
        :patterns,
        :total_count,
        :unique_count
      ])
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Map.new()

    Map.put(dsv, :profile, profile)
  end

  def with_profile_attrs(dsv, _), do: Map.put(dsv, :profile, nil)

  defp query_fields_to_enrich_opts(nil), do: @controller_enrich_attrs

  defp query_fields_to_enrich_opts(query_fields),
    do: Enum.flat_map(query_fields, &field_to_enrich_opt/1)

  defp field_to_enrich_opt(:siblings), do: [:siblings]
  defp field_to_enrich_opt(:versions), do: [:versions]
  defp field_to_enrich_opt(:implementation_count), do: [:implementation_count]
  defp field_to_enrich_opt(:data_structure_link_count), do: [:data_structure_link_count]
  defp field_to_enrich_opt(:degree), do: [:degree]
  defp field_to_enrich_opt(:profile), do: [:profile]
  defp field_to_enrich_opt(:source), do: [:source]
  defp field_to_enrich_opt(:system), do: [:system]
  defp field_to_enrich_opt(:grant), do: [:grant]
  defp field_to_enrich_opt(:grants), do: [:grants]
  defp field_to_enrich_opt(:links), do: [:links]
  defp field_to_enrich_opt(:note), do: [:published_note]
  defp field_to_enrich_opt(:relations), do: [:relations, :relation_links]

  defp field_to_enrich_opt(:metadata),
    do: [:with_protected_metadata, :metadata_versions]

  # These static preloads are present even if degree or links GraphQL fields
  # are not requested.
  defp field_to_enrich_opt(:data_fields),
    do: [
      :data_fields,
      :data_field_degree,
      :data_field_links
    ]

  defp field_to_enrich_opt(_), do: []

  def enrich_opts(data_structure, %{user_id: user_id} = claims, enriches) do
    Enum.filter(@base_enrich_attrs ++ enriches, fn
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
          permit?(DataStructures, :manage_grant_removal, claims, data_structure) and
            permit?(DataStructures, :manage_foreign_grant_removal, claims, data_structure),
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

  def get_grant_user_permissions(data_structure, claims) do
    %{
      request_grant: can_request_grant?(claims, data_structure),
      update_grant_removal:
        permit?(DataStructures, :manage_grant_removal, claims, data_structure),
      create_foreign_grant_request:
        permit?(DataStructures, :create_foreign_grant_request, claims, data_structure)
    }
  end

  defp actions(claims, %{data_structure: data_structure} = _dsv) do
    [:link_data_structure, :link_structure_to_structure, :manage_structure_acl_entry]
    |> Enum.filter(&permit?(DataStructures, &1, claims, data_structure))
    |> Map.new(fn
      :link_data_structure ->
        {:create_link, true}

      :link_structure_to_structure ->
        {
          :create_struct_to_struct_link,
          %{
            href: "/api/v2",
            method: "POST"
          }
        }

      :manage_structure_acl_entry ->
        {:manage_structure_acl_entry, %{}}
    end)
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

  defp add_data_fields(%{data_fields: data_fields} = dsv) do
    field_structures = Enum.map(data_fields, &field_structure_json/1)
    Map.put(dsv, :data_fields, field_structures)
  end

  defp add_data_fields(dsv) do
    Map.put(dsv, :data_fields, [])
  end

  defp field_structure_json(
         %{
           class: "field",
           data_structure: %{profile: profile, alias: alias_name}
         } = dsv
       ) do
    dsv
    |> with_profile_attrs(profile)
    |> Map.put(:alias, alias_name)
  end

  def merge_metadata(%{metadata_versions: [_ | _] = metadata_versions} = dsv) do
    %{fields: mutable_metadata} =
      case Enum.max_by(metadata_versions, & &1.version) do
        %{deleted_at: deleted_at} = _version when deleted_at != nil ->
          %{fields: %{}}

        latest_metadata ->
          latest_metadata
      end

    Map.update(dsv, :metadata, mutable_metadata, fn
      nil ->
        mutable_metadata

      %{} = metadata ->
        Map.merge(
          metadata,
          mutable_metadata,
          fn
            # Merge metadata and mutable_metadata @protected fields.
            # If there is a conflict in the @protected content, the one from
            # mutable metadata (rightmost in the Map.merge) will prevail.
            @protected, mp, mmp -> Map.merge(mp, mmp)
            _key, _mp, mmp -> mmp
          end
        )
    end)
  end

  def merge_metadata(dsv), do: dsv
end
