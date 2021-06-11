defmodule TdDd.CSV.Download do
  @moduledoc """
  Helper module to download structures.
  """

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

  @lineage_headers [
    "source_external_id",
    "source_name",
    "source_class",
    "target_external_id",
    "target_name",
    "target_class",
    "relation_type"
  ]

  def to_csv(structures, header_labels \\ nil) do
    structures_by_type = Enum.group_by(structures, &Map.get(&1, :type))
    types = Map.keys(structures_by_type)

    structure_types = Enum.reduce(types, %{}, &Map.put(&2, &1, enrich_template(&1)))

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

  defp template_structures_to_csv(
         %{template: %{content: content = [_ | _]}},
         structures,
         header_labels,
         add_separation
       ) do
    content = Format.flatten_content_fields(content)
    content_fields = Enum.reduce(content, [], &(&2 ++ [Map.take(&1, ["name", "values", "type"])]))
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
    Enum.map(structures, fn structure ->
      content = structure.df_content

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

      Enum.reduce(content_fields, values, &(&2 ++ [&1 |> get_content_field(content)]))
    end)
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

  defp get_content_field(_template, nil), do: ""

  defp get_content_field(%{"type" => "url", "name" => name}, content) do
    content
    |> Map.get(name, [])
    |> content_to_list()
    |> Enum.map(&Map.get(&1, "url_value"))
    |> Enum.filter(&(not is_nil(&1)))
    |> Enum.join(", ")
  end

  defp get_content_field(%{"type" => type, "name" => name}, content)
       when type in ["domain", "system"] do
    content
    |> Map.get(name, [])
    |> content_to_list()
    |> Enum.map(&Map.get(&1, "name"))
    |> Enum.reject(&is_nil/1)
    |> Enum.join(", ")
  end

  defp get_content_field(
         %{
           "type" => "string",
           "name" => name,
           "values" => %{"fixed_tuple" => values}
         },
         content
       ) do
    content
    |> Map.get(name, [])
    |> content_to_list()
    |> Enum.map(fn map_value ->
      Enum.find(values, fn %{"value" => value} -> value == map_value end)
    end)
    |> Enum.map(&Map.get(&1, "text", ""))
    |> Enum.join(", ")
  end

  defp get_content_field(%{"type" => "table"}, _content), do: ""

  defp get_content_field(%{"name" => name}, content) do
    Map.get(content, name, "")
  end

  defp enrich_template(type) do
    type
    |> DataStructureTypes.get_data_structure_type_by_type!()
    |> case do
      nil ->
        nil

      structure_type ->
        DataStructureTypes.enrich_template(structure_type)
    end
  end

  defp content_to_list(nil), do: []

  defp content_to_list([""]), do: []

  defp content_to_list(""), do: []

  defp content_to_list(content) when is_list(content), do: content

  defp content_to_list(content), do: [content]

  defp build_empty_list(acc, l) when l < 1, do: acc
  defp build_empty_list(acc, l), do: ["" | build_empty_list(acc, l - 1)]

  defp get_domain(%{domain: %{"name" => name}}), do: name
  defp get_domain(_), do: nil
end
