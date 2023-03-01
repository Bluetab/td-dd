defmodule TdDdWeb.Resolvers.Structures do
  @moduledoc """
  Absinthe resolvers for data structures and related entities
  """

  alias TdDd.DataStructures
  alias TdDd.DataStructures.DataStructureLinks
  alias TdDd.DataStructures.DataStructureVersions
  alias TdDd.DataStructures.Relations
  alias TdDd.DataStructures.Tags
  alias TdDd.Utils.CollectionUtils

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
       |> Map.put(:actions, actions)
       |> Map.put(:user_permissions, user_permissions)}
    else
      {:claims, nil} -> {:error, :unauthorized}
      {:enriched_dsv, nil} -> {:error, :not_found}
      {:enriched_dsv, :forbidden} -> {:error, :forbidden}
    end
  end

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

  def note(_dsv, _args, _resolution), do: {:ok, nil}

  defp handle_note_select(content, dsv, select_fields \\ nil)

  defp handle_note_select(content, dsv, [_ | _] = select_fields) do
    content
    |> DataStructures.get_cached_content(dsv)
    |> Map.take(select_fields)
  end

  defp handle_note_select(content, dsv, nil), do: DataStructures.get_cached_content(content, dsv)
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

  def data_structure_links(%{} = data_structure, _args, _resolution) do
    {:ok, DataStructureLinks.links(data_structure)}
  end

  defp claims(%{context: %{claims: claims}}), do: claims
  defp claims(_), do: nil
end
