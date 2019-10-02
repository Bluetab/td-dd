defmodule TdDd.CSV.Download do
  @moduledoc """
  Helper module to download structures.
  """

  alias TdCache.TemplateCache

  def to_csv(structures, header_labels) do
    structures_by_type = Enum.group_by(structures, &(Map.get(&1, :type) ))
    types = Map.keys(structures_by_type)

    templates_by_type = Enum.reduce(types, %{}, &Map.put(&2, &1, TemplateCache.get_by_name!(&1)))

    list =
      Enum.reduce(types, [], fn type, acc ->
        structures = Map.get(structures_by_type, type)
        template = Map.get(templates_by_type, type)

        csv_list = template_structures_to_csv(template, structures, header_labels, !Enum.empty?(acc))
        acc ++ csv_list
      end)

    to_string(list)
  end

  defp template_structures_to_csv(nil, structures, header_labels, add_separation) do
    headers = build_headers(header_labels)
    structures_list = structures_to_list(structures)
    export_to_csv(headers, structures_list, add_separation)
  end

  defp template_structures_to_csv(template, structures, header_labels, add_separation) do
    content = template.content
    content_fields = Enum.reduce(content, [], &(&2 ++ [Map.take(&1, ["name", "values", "type"])]))
    content_labels = Enum.reduce(content, [], &(&2 ++ [Map.get(&1, "label")]))
    headers = build_headers(header_labels)
    headers = headers ++ content_labels
    structures_list = structures_to_list(structures, content_fields)
    export_to_csv(headers, structures_list, add_separation)
  end

  defp structures_to_list(structures, content_fields \\ []) do
    Enum.map(structures, fn structure ->
      content = structure.df_content

      values = [
        structure.type,
        structure.name,
        structure.external_id,
        structure.group,
        structure.ou,
        Map.get(structure.system, "name"),
        Enum.join(structure.path, " > "),
        structure.description,
        structure.inserted_at,
        structure.deleted_at
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

  defp build_headers(header_labels) do
    [
      "type",
      "name",
      "external_id",
      "group",
      "ou",
      "system",
      "path",
      "description",
      "inserted_at",
      "deleted_at"
    ]
    |> Enum.map(fn h -> Map.get(header_labels, h, h) end)
  end

  defp get_content_field(_template, nil) do
    ""
  end

  defp get_content_field(%{"type" => "url", "name" => name}, content) do
    content
    |> Map.get(name, [])
    |> content_to_list()
    |> Enum.map(&Map.get(&1, "url_value"))
    |> Enum.filter(&(not is_nil(&1)))
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

  defp content_to_list([""]), do: []

  defp content_to_list(""), do: []

  defp content_to_list(content) when is_list(content), do: content

  defp content_to_list(content), do: [content]

  defp build_empty_list(acc, l) when l < 1, do: acc
  defp build_empty_list(acc, l), do: ["" | build_empty_list(acc, l - 1)]
end
