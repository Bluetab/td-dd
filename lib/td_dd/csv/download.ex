defmodule TdDd.CSV.Download do
  @moduledoc """
  Helper module to download structures.
  """

  alias TdCache.DomainCache
  alias TdCache.HierarchyCache
  alias TdDd.DataStructures.DataStructureTypes
  alias TdDfLib.Format

  @headers [
    "type",
    "name",
    "group",
    "domain",
    "system",
    "path",
    "description",
    "external_id",
    "inserted_at"
  ]

  @editable_headers [:external_id, :name, :type, :path]

  @lineage_headers [
    "source_external_id",
    "source_name",
    "source_class",
    "target_external_id",
    "target_name",
    "target_class",
    "relation_type"
  ]

  @grant_headers [
    "user_name",
    "data_structure_name",
    "start_date",
    "end_date",
    "metadata",
    "mutable_metadata"
  ]

  def to_csv(structures, header_labels \\ nil) do
    structures_by_type = Enum.group_by(structures, &Map.get(&1, :type))
    types = Map.keys(structures_by_type)

    structure_types =
      Enum.reduce(types, %{}, &Map.put(&2, &1, DataStructureTypes.get_by(name: &1)))

    list =
      Enum.reduce(types, [], fn type, acc ->
        structures = Map.get(structures_by_type, type)
        structure_type = Map.get(structure_types, type)

        csv_list =
          template_structures_to_csv(structure_type, structures, header_labels, !Enum.empty?(acc))

        acc ++ csv_list
      end)

    to_string(list)
  end

  def to_editable_csv(structures) do
    type_fields =
      structures
      |> Enum.map(& &1.type)
      |> Enum.uniq()
      |> Enum.map(&DataStructureTypes.get_by(name: &1))
      |> Enum.flat_map(&type_editable_fields/1)
      |> Enum.uniq_by(&Map.get(&1, "name"))

    type_headers = Enum.map(type_fields, &Map.get(&1, "name"))

    headers = @editable_headers ++ type_headers
    {:ok, domain_name_map} = DomainCache.id_to_name_map()
    core = Enum.map(structures, &editable_structure_values(&1, type_fields, domain_name_map))

    [headers | core]
    |> CSV.encode(separator: ?;)
    |> Enum.to_list()
    |> to_string()
  end

  defp type_editable_fields(%{template: %{content: content}}) when is_list(content) do
    Enum.flat_map(content, &Map.get(&1, "fields"))
  end

  defp type_editable_fields(_type), do: []

  defp editable_structure_values(%{note: nil} = structure, type_headers, _domain_name_map) do
    structure_values = Enum.map(@editable_headers, &editable_structure_value(structure, &1))
    empty_values = List.duplicate(nil, length(type_headers))
    structure_values ++ empty_values
  end

  defp editable_structure_values(%{note: content} = structure, type_fields, domain_name_map) do
    structure_values = Enum.map(@editable_headers, &editable_structure_value(structure, &1))
    content_values = Enum.map(type_fields, &get_content_field(&1, content, domain_name_map, true))
    structure_values ++ content_values
  end

  defp editable_structure_value(%{path: path}, :path), do: Enum.join(path, " > ")

  defp editable_structure_value(structure, field), do: Map.get(structure, field)

  def linage_to_csv(contains, depends, header_labels \\ nil) do
    headers = build_headers(header_labels, @lineage_headers)
    contains = lineage_csv_rows(contains, "CONTAINS")
    depends = lineage_csv_rows(depends, "DEPENDS")
    list = [headers] ++ contains ++ depends

    list
    |> CSV.encode(separator: ?;)
    |> Enum.to_list()
    |> List.to_string()
  end

  def to_csv_grants(grants, header_labels \\ nil) do
    grants_by_data_structures =
      Enum.group_by(grants, &Kernel.get_in(&1, ["data_structure_version", :name]))

    headers = build_headers(header_labels, @grant_headers)

    grant_list =
      Enum.reduce(
        grants_by_data_structures,
        [],
        fn {_data_structure, grants}, acc ->
          [grants_to_list(grants) | acc]
        end
      )
      |> Enum.flat_map(fn x -> x end)

    export_to_csv(headers, grant_list, false)
    |> List.to_string()
  end

  defp template_structures_to_csv(
         %{template: %{content: content = [_ | _]}},
         structures,
         header_labels,
         add_separation
       ) do
    content = Format.flatten_content_fields(content)

    content_fields =
      Enum.reduce(content, [], &(&2 ++ [Map.take(&1, ["name", "values", "type", "cardinality"])]))

    content_labels = Enum.reduce(content, [], &(&2 ++ [Map.get(&1, "label")]))
    headers = build_headers(header_labels)
    headers = headers ++ content_labels
    structures_list = structures_to_list(structures, content_fields)
    export_to_csv(headers, structures_list, add_separation)
  end

  defp template_structures_to_csv(_structure_type, structures, header_labels, add_separation) do
    headers = build_headers(header_labels)
    structures_list = structures_to_list(structures)
    export_to_csv(headers, structures_list, add_separation)
  end

  defp structures_to_list(structures, content_fields \\ []) do
    {:ok, domain_name_map} = DomainCache.id_to_name_map()

    Enum.map(structures, &structure_to_row(&1, content_fields, domain_name_map))
  end

  defp structure_to_row(structure, content_fields, domain_name_map) do
    content = structure.note

    values = [
      structure.type,
      structure.name,
      structure.group,
      get_domain(structure),
      Map.get(structure.system, "name"),
      Enum.join(structure.path, " > "),
      structure.description,
      structure.external_id,
      structure.inserted_at
    ]

    Enum.reduce(
      content_fields,
      values,
      &(&2 ++ [get_content_field(&1, content, domain_name_map, false)])
    )
  end

  defp grants_to_list(grants) do
    Enum.map(
      grants,
      fn grant ->
        [
          grant.user.full_name,
          grant.data_structure_version.name,
          grant.start_date,
          grant.end_date,
          Jason.encode!(grant.data_structure_version.metadata),
          Jason.encode!(grant.data_structure_version.mutable_metadata)
        ]
      end
    )
  end

  defp export_to_csv(headers, structure_list, add_separation) do
    list_to_encode =
      case add_separation do
        true ->
          empty = build_empty_list([], length(headers))
          [empty, empty, headers] ++ structure_list

        false ->
          [headers | structure_list]
      end

    list_to_encode
    |> CSV.encode(separator: ?;)
    |> Enum.to_list()
  end

  defp lineage_csv_rows(relations, type) do
    Enum.map(relations, &relation_row(&1, type))
  end

  defp relation_row(relation, type) do
    source = relation[:source]
    target = relation[:target]

    [
      Map.get(source, :external_id),
      Map.get(source, :name),
      Map.get(source, :class),
      Map.get(target, :external_id),
      Map.get(target, :name),
      Map.get(target, :class),
      type
    ]
  end

  defp build_headers(header_labels, headers \\ @headers)

  defp build_headers(nil, headers) do
    headers
  end

  defp build_headers(header_labels, headers) do
    Enum.map(headers, fn h -> Map.get(header_labels, h, h) end)
  end

  defp get_content_field(_template, nil, _domain_map, _editable), do: ""

  defp get_content_field(%{"type" => "url", "name" => name}, content, _domain_map, _editable) do
    content
    |> Map.get(name, [])
    |> content_to_list()
    |> Enum.map(&Map.get(&1, "url_value"))
    |> Enum.reject(&is_nil/1)
    |> Enum.join(", ")
  end

  defp get_content_field(%{"type" => "domain", "name" => name}, content, domain_map, _editable) do
    content
    |> Map.get(name)
    |> List.wrap()
    |> Enum.map(&Map.get(domain_map, &1))
    |> Enum.reject(&is_nil/1)
    |> Enum.join(", ")
  end

  defp get_content_field(%{"type" => "system", "name" => name}, content, _domain_map, _editable) do
    content
    |> Map.get(name, [])
    |> content_to_list()
    |> Enum.map(&Map.get(&1, "name"))
    |> Enum.reject(&is_nil/1)
    |> Enum.join(", ")
  end

  defp get_content_field(
         %{"type" => "hierarchy", "name" => name, "values" => %{"hierarchy" => hierarchy_id}},
         content,
         _domain_name_map,
         editable
       ) do
    {:ok, nodes} = HierarchyCache.get(hierarchy_id, :nodes)

    content
    |> Map.get(name, [])
    |> content_to_list()
    |> Enum.map(
      &Enum.find(nodes, fn %{"node_id" => node_id} ->
        [_hierarchy_id, content_node_id] = String.split(&1, "_")
        node_id === String.to_integer(content_node_id)
      end)
    )
    |> Enum.reject(&is_nil/1)
    |> Enum.map_join(", ", fn %{"node_id" => id, "name" => name} ->
      if editable, do: id, else: name
    end)
  end

  defp get_content_field(
         %{
           "type" => "string",
           "name" => name,
           "values" => %{"fixed_tuple" => values}
         },
         content,
         _domain_map,
         _editable
       ) do
    content
    |> Map.get(name, [])
    |> content_to_list()
    |> Enum.map(&Enum.find(values, fn %{"value" => value} -> value == &1 end))
    |> Enum.reject(&is_nil/1)
    |> Enum.map_join(", ", &Map.get(&1, "text", ""))
  end

  defp get_content_field(%{"type" => "table"}, _content, _domain_map, _editable),
    do: ""

  defp get_content_field(
         %{
           "name" => name,
           "cardinality" => cardinality
         },
         content,
         _domain_map,
         _editable
       )
       when cardinality in ["+", "*"] do
    content
    |> Map.get(name, [])
    |> content_to_list()
    |> Enum.join("|")
  end

  defp get_content_field(%{"name" => name}, %{} = content, _domain_map, _editable) do
    Map.get(content, name, "")
  end

  defp content_to_list(nil), do: []

  defp content_to_list([""]), do: []

  defp content_to_list(""), do: []

  defp content_to_list(content) when is_list(content), do: content

  defp content_to_list(content), do: [content]

  defp build_empty_list(acc, l) when l < 1, do: acc
  defp build_empty_list(acc, l), do: ["" | build_empty_list(acc, l - 1)]

  defp get_domain(%{domain_ids: [_ | _] = domain_ids}) do
    Enum.map_join(domain_ids, "|", fn id ->
      id
      |> DomainCache.get!()
      |> make_domain_path()
    end)
  end

  defp get_domain(%{domain: %{"name" => name}}), do: name
  defp get_domain(_), do: nil

  defp make_domain_path(domain, domain_path \\ [])

  defp make_domain_path(nil, _), do: ""

  defp make_domain_path(%{parent_id: nil, name: name}, domain_path),
    do: Enum.join([name | domain_path], "/")

  defp make_domain_path(%{parent_id: parent_id, name: name}, domain_path) do
    new_domain_path = [name | domain_path]

    parent_id
    |> DomainCache.get!()
    |> make_domain_path(new_domain_path)
  end
end
