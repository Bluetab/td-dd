defmodule TdDd.CSV.Download do
  @moduledoc """
  Helper module to download structures.
  """

  alias TdCache.DomainCache
  alias TdDd.DataStructures.DataStructureTypes
  alias TdDfLib.Format
  alias TdDfLib.Parser

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

  @headers_extended [
    "type",
    "tech_name",
    "alias_name",
    "link_to_structure",
    "group",
    "domain",
    "system",
    "path",
    "description",
    "external_id",
    "inserted_at"
  ]

  @editable_headers [
    :external_id,
    :name,
    :type,
    :path
  ]
  @editable_extra_headers [
    "tech_name",
    "alias_name",
    "link_to_structure"
  ]

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

  def to_csv(structures, header_labels, structure_url_schema, lang) do
    structures
    |> Enum.group_by(&Map.get(&1, :type))
    |> Enum.reduce([], fn {type, structures}, acc ->
      content =
        [name: type]
        |> DataStructureTypes.get_by()
        |> then(fn
          %{template: %{content: content = [_ | _]}} ->
            Format.flatten_content_fields(content, lang)

          _ ->
            []
        end)

      content_labels = Enum.map(content, &Map.get(&1, "definition"))

      headers =
        if is_nil(structure_url_schema) do
          build_headers(header_labels) ++ content_labels
        else
          build_headers(header_labels, @headers_extended) ++ content_labels
        end

      content_fields =
        Enum.map(content, &Map.take(&1, ["name", "values", "type", "cardinality", "label"]))

      structures_list =
        Enum.map(structures, fn %{note: content} = structure ->
          structure
          |> get_standar_fields(structure_url_schema)
          |> Parser.append_parsed_fields(content_fields, content,
            lang: lang,
            domain_type: :with_domain_name
          )
        end)

      csv_list = export_to_csv(headers, structures_list, !Enum.empty?(acc))

      acc ++ csv_list
    end)
    |> to_string
  end

  def to_editable_csv(structures, structure_url_schema \\ nil) do
    type_fields =
      structures
      |> Enum.map(& &1.type)
      |> Enum.uniq()
      |> Enum.map(&DataStructureTypes.get_by(name: &1))
      |> Enum.flat_map(&type_editable_fields/1)
      |> Enum.uniq_by(&Map.get(&1, "name"))

    type_headers = Enum.map(type_fields, &Map.get(&1, "name"))

    headers = get_editable_headers(type_headers, structure_url_schema)

    core =
      Enum.map(structures, fn %{note: content} = structure ->
        @editable_headers
        |> Enum.map(&editable_structure_value(structure, &1))
        |> add_editable_extra_fields(structure, structure_url_schema)
        |> Parser.append_parsed_fields(type_fields, content, domain_type: :with_domain_external_id)
      end)

    [headers | core]
    |> CSV.encode(separator: ?;)
    |> Enum.to_list()
    |> to_string()
  end

  defp get_structure_alias(%{note: %{"alias" => alias}}), do: alias

  defp get_structure_alias(_), do: ""

  defp get_standar_fields(structure, nil) do
    [
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
  end

  defp get_standar_fields(structure, structure_url_schema) do
    [
      structure.type,
      Map.get(structure, :original_name, structure.name),
      get_structure_alias(structure),
      get_structure_url_schema(structure_url_schema, structure.data_structure_id),
      structure.group,
      get_domain(structure),
      Map.get(structure.system, "name"),
      Enum.join(structure.path, " > "),
      structure.description,
      structure.external_id,
      structure.inserted_at
    ]
  end

  defp get_structure_url_schema(url_schema, structure_id) do
    if String.contains?(url_schema, "/:id") do
      String.replace(url_schema, ":id", to_string(structure_id))
    else
      nil
    end
  end

  defp get_editable_headers(type_headers, nil) do
    @editable_headers ++ type_headers
  end

  defp get_editable_headers(type_headers, _structure_url_schema) do
    @editable_headers ++ @editable_extra_headers ++ type_headers
  end

  defp add_editable_extra_fields(editable_fields, _, nil), do: editable_fields

  defp add_editable_extra_fields(editable_fields, structure, structure_url_schema) do
    editable_fields ++
      [
        Map.get(structure, :original_name, structure.name),
        get_structure_alias(structure),
        get_structure_url_schema(structure_url_schema, structure.data_structure_id)
      ]
  end

  defp type_editable_fields(%{template: %{content: content}}) when is_list(content) do
    Enum.flat_map(content, &Map.get(&1, "fields"))
  end

  defp type_editable_fields(_type), do: []

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
