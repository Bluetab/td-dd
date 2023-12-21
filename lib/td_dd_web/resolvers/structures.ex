defmodule TdDdWeb.Resolvers.Structures do
  @moduledoc """
  Absinthe resolvers for data structures and related entities
  """

  import Absinthe.Resolution.Helpers, only: [on_load: 2]

  alias TdCore.Utils.CollectionUtils
  alias TdDd.DataStructures
  alias TdDd.DataStructures.DataStructureLinks
  alias TdDd.DataStructures.DataStructureVersions
  alias TdDd.DataStructures.Relations
  alias TdDd.DataStructures.Tags

  @permissions_attrs [:with_protected_metadata, :with_confidential, :profile]

  def data_structures(_parent, args, _resolution) do
    {:ok, DataStructures.list_data_structures(args)}
  end

  def data_structure(_parent, %{id: id} = _args, resolution) do
    with {:claims, claims} when not is_nil(claims) <- {:claims, claims(resolution)},
         {:data_structure, %{} = structure} <-
           {:data_structure, DataStructures.get_data_structure(id)},
         :ok <- Bodyguard.permit(DataStructures, :view_data_structure, claims, structure) do
      {:ok, structure}
    else
      {:claims, nil} -> {:error, :unauthorized}
      {:data_structure, nil} -> {:error, :not_found}
      {:error, :forbidden} -> {:error, :forbidden}
    end
  end

  def data_structure(%{data_structure_id: id}, _args, resolution),
    do: data_structure(%{}, %{id: id}, resolution)

  def data_structure_versions(_parent, args, _resolution) do
    {:ok, DataStructures.list_data_structure_versions(args)}
  end

  def data_structure_relations(_parent, args, _resolution) do
    {:ok, Relations.list_data_structure_relations(args)}
  end

  def data_structure_version(
        _parent,
        %{data_structure_id: data_structure_id, version: version},
        resolution
      ) do
    query_fields =
      resolution
      |> Map.get(:definition)
      |> Map.get(:selections)
      |> Enum.map(fn %{schema_node: %{identifier: identifier}} -> identifier end)

    with {:claims, claims} when not is_nil(claims) <- {:claims, claims(resolution)},
         {:enriched_dsv, [_ | _] = enriched_dsv} <-
           {:enriched_dsv,
            DataStructureVersions.enriched_data_structure_version(
              claims,
              data_structure_id,
              version,
              query_fields
            )},
         dsv <- enriched_dsv[:data_structure_version],
         actions <- enriched_dsv[:actions],
         user_permissions <- enriched_dsv[:user_permissions] do
      {:ok,
       dsv
       |> maybe_check_siblings_permission(claims)
       |> Map.put(:actions, actions)
       |> Map.put(:user_permissions, user_permissions)}
    else
      {:claims, nil} -> {:error, :unauthorized}
      {:enriched_dsv, nil} -> {:error, :not_found}
      {:enriched_dsv, :forbidden} -> {:error, :forbidden}
    end
  end

  defp maybe_check_siblings_permission(%{siblings: [_ | _] = dsv_sibling} = dsv, claims) do
    filtered_sibling = Enum.filter(dsv_sibling, &check_structure_related_permision(&1, claims))
    Map.put(dsv, :siblings, filtered_sibling)
  end

  defp maybe_check_siblings_permission(dsv, _claims), do: dsv

  def domain_id(%{domain_ids: domain_ids}, _args, _resolution) do
    domain_id =
      case domain_ids do
        [domain_id | _] -> domain_id
        _ -> nil
      end

    {:ok, domain_id}
  end

  def data_structure_version_path(%{id: id}, _args, _resolution) do
    path =
      id
      |> ds_path
      |> Enum.map(&Map.get(&1, "name"))

    {:ok, path}
  end

  def data_structure_version_path_with_ids(%{id: id}, _args, _resolution) do
    path =
      id
      |> ds_path
      |> Enum.map(&CollectionUtils.atomize_keys(&1))

    {:ok, path}
  end

  def add_alias(%{data_structure: %{alias: alias}}, _args, _resolution), do: {:ok, alias}

  def add_alias(%{alias: alias}, _args, _resolution), do: {:ok, alias}

  def add_alias(_dsv, _args, _resolution), do: {:ok, nil}

  def note(
        %{data_structure: %{published_note: %{df_content: %{} = content}}} = dsv,
        %{select_fields: select_fields},
        _resolution
      ) do
    {:ok, handle_note_select(content, dsv, select_fields)}
  end

  def note(
        %{published_note: %{df_content: %{} = content}} = dsv,
        %{select_fields: select_fields},
        _resolution
      ) do
    {:ok, handle_note_select(content, dsv, select_fields)}
  end

  def note(
        %{data_structure: %{published_note: %{df_content: %{} = content}}} = dsv,
        _args,
        _resolution
      ) do
    {:ok, handle_note_select(content, dsv)}
  end

  def note(%{published_note: %{df_content: %{} = content}} = dsv, _args, _resolution) do
    {:ok, handle_note_select(content, dsv)}
  end

  def note(_dsv, _args, _resolution), do: {:ok, %{has_note: false}}

  defp handle_note_select(content, dsv, select_fields \\ nil)

  defp handle_note_select(content, dsv, [_ | _] = select_fields) do
    content
    |> DataStructures.get_cached_content(dsv)
    |> Map.take(select_fields)
  end

  defp handle_note_select(content, dsv, select_fields)
       when is_nil(select_fields) or select_fields == [] do
    DataStructures.get_cached_content(content, dsv)
  end

  defp handle_note_select(_content, _dsv, _), do: nil

  def ancestry(%{path: [_ | _] = path}, _args, _resolution), do: {:ok, path}

  def ancestry(_, _args, _resolution), do: {:ok, []}

  def actions(%{actions: actions}, _args, _resolution) do
    {:ok, transform_create_link(actions)}
  end

  def actions(_, _, _), do: {:ok, nil}

  defp transform_create_link(%{create_link: true} = actions), do: %{actions | create_link: %{}}
  defp transform_create_link(actions), do: actions

  def relations(%{relations: %{children: children, parents: parents}}, _args, _resolution) do
    {:ok,
     %{
       children: Enum.map(children, &embedded_relation/1),
       parents: Enum.map(parents, &embedded_relation/1)
     }}
  end

  defp embedded_relation(%{links: links} = struct) do
    struct
    |> Map.delete(:links)
    |> embedded_relation()
    |> Map.put(:links, links)
  end

  defp embedded_relation(%{version: version, relation: relation, relation_type: relation_type}) do
    %{
      id: relation.id,
      structure: version,
      relation_type: relation_type
    }
  end

  defp ds_path(id) do
    [ids: [id]]
    |> DataStructures.enriched_structure_versions()
    |> hd()
    |> Map.get(:path)
  end

  def available_tags(%{} = structure, _args, resolution) do
    with {:claims, %{} = claims} <- {:claims, claims(resolution)},
         :ok <- Bodyguard.permit(DataStructures, :tag, claims, structure) do
      {:ok, Tags.list_available_tags(structure)}
    else
      {:claims, nil} -> {:error, :unauthorized}
      _ -> {:ok, []}
    end
  end

  def structure_tags(%{} = data_structure, _args, _resolution) do
    {:ok, Tags.tags(data_structure)}
  end

  def metadata(
        %TdDd.DataStructures.DataStructureVersion{data_structure: %{id: _} = ds} = dsv,
        _args,
        %{context: %{claims: claims}} = _resolution
      ) do
    opts = get_permissions_opts(ds, claims)

    %{metadata: metadata} =
      dsv
      |> DataStructures.get_mutable_metadata([metadata_versions: true] ++ opts)
      |> DataStructureVersions.merge_metadata()

    {:ok, metadata}
  end

  def metadata(
        %TdDd.DataStructures.DataStructureVersion{data_structure_id: ds_id} = dsv,
        args,
        resolution
      ) do
    data_structure = DataStructures.get_data_structure!(ds_id)

    dsv
    |> Map.put(:data_structure, data_structure)
    |> metadata(args, resolution)
  end

  def children(parent, args, %{context: %{loader: loader, claims: claims}}) do
    batch_key =
      Map.to_list(args) ++
        [
          {:add_children, parent},
          {:preload, [:classifications, :data_structure, :published_note]}
        ]

    loader
    |> Dataloader.load(TdDd.DataStructures, {:children, batch_key}, parent)
    |> on_load(fn loader ->
      children =
        loader
        |> Dataloader.get(TdDd.DataStructures, {:children, batch_key}, parent)
        |> Enum.filter(&check_structure_related_permision(&1, claims))
        |> Enum.map(&add_classes/1)

      {:ok, children}
    end)
  end

  def parents(child, args, %{context: %{loader: loader, claims: claims}}) do
    batch_key =
      Map.to_list(args) ++
        [{:add_parents, child}, {:preload, [:classifications, :data_structure, :published_note]}]

    loader
    |> Dataloader.load(TdDd.DataStructures, {:parents, batch_key}, child)
    |> on_load(fn loader ->
      parents =
        loader
        |> Dataloader.get(TdDd.DataStructures, {:parents, batch_key}, child)
        |> Enum.filter(&check_structure_related_permision(&1, claims))
        |> Enum.map(&add_classes/1)

      {:ok, parents}
    end)
  end

  def profile(%{data_structure: ds} = dsv, _args, %{context: %{claims: claims}} = _resolution) do
    opts = get_permissions_opts(ds, claims)

    profile = if Keyword.get(opts, :profile), do: DataStructures.get_profile!(dsv), else: nil

    {:ok, profile}
  end

  def links(dsv, _args, _resolution) do
    {:ok, DataStructures.get_structure_links(dsv)}
  end

  def data_structure_links(%{} = data_structure, _args, _resolution) do
    {:ok, DataStructureLinks.links(data_structure)}
  end

  defp check_structure_related_permision(%{data_structure: data_structure}, claims) do
    case Bodyguard.permit(DataStructures, :view_data_structure, claims, data_structure) do
      :ok -> true
      _ -> false
    end
  end

  defp add_classes(%{classifications: [_ | _] = classifications} = struct) do
    classes = Map.new(classifications, fn %{name: name, class: class} -> {name, class} end)
    Map.put(struct, :classes, classes)
  end

  defp add_classes(dsv), do: dsv

  defp claims(%{context: %{claims: claims}}), do: claims
  defp claims(_), do: nil

  defp get_permissions_opts(ds, claims) do
    ds
    |> DataStructureVersions.enrich_opts(claims, [:profile])
    |> Enum.filter(fn e ->
      e in @permissions_attrs
    end)
    |> Enum.map(fn permission ->
      {permission, true}
    end)
  end
end
