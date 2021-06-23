defmodule TdDq.Implementations.Download do
  @moduledoc """
  Helper module to download implementations.
  """

  alias TdCache.TemplateCache
  alias TdDfLib.Format

  def to_csv(implementations, header_labels, content_labels) do
    implementations = Enum.group_by(implementations, &group_by_type/1)
    types = Map.keys(implementations)
    templates = Enum.reduce(types, %{}, &Map.put(&2, &1, TemplateCache.get_by_name!(&1)))
    build_csv(implementations, types, templates, header_labels, content_labels)
  end

  defp group_by_type(implementation) do
    implementation
    |> Map.get(:rule)
    |> Map.get(:df_name)
  end

  defp build_csv(implementations, types, templates, header_labels, content_labels) do
    types
    |> Enum.reduce(
      [],
      &build_rows(implementations, templates, header_labels, content_labels, &1, &2)
    )
    |> to_string()
  end

  defp build_rows(implementations, templates, header_labels, content_labels, type, acc) do
    implementations = Map.get(implementations, type)
    template = Map.get(templates, type)
    acc ++ csv_format(template, implementations, header_labels, content_labels, acc)
  end

  defp csv_format(nil, implementations, header_labels, content_labels, acc) do
    headers = build_headers(header_labels)

    implementations = format_implementations(content_labels, implementations)
    export(headers, implementations, acc)
  end

  defp csv_format(template, implementations, header_labels, content_labels, acc) do
    content = Format.flatten_content_fields(template.content)
    fields = Enum.reduce(content, [], &(&2 ++ [Map.take(&1, ["name", "values", "type"])]))

    field_headers = Enum.reduce(content, [], &(&2 ++ [Map.get(&1, "label")]))
    headers = build_headers(header_labels)
    headers = headers ++ field_headers

    implementations = format_implementations(content_labels, implementations, fields)
    export(headers, implementations, acc)
  end

  defp format_implementations(content_labels, implementations, fields \\ []) do
    Enum.reduce(implementations, [], fn implementation, acc ->
      rule = Map.get(implementation, :rule)
      content = Map.get(rule, :df_content)

      values = [
        implementation.implementation_key,
        implementation.implementation_type,
        translate("executable.#{implementation.executable}", content_labels),
        rule.name,
        rule.df_name,
        rule.goal,
        rule.minimum,
        get_in(implementation, [:current_business_concept_version, :name]),
        get_in(implementation, [:execution_result_info, :date]),
        get_in(implementation, [:execution_result_info, :result]),
        implementation
        |> get_in([:execution_result_info, :result_text])
        |> translate(content_labels),
        implementation.inserted_at
      ]

      acc ++ [Enum.reduce(fields, values, &(&2 ++ [get_content_field(&1, content)]))]
    end)
  end

  defp export(headers, implementations, []) do
    [headers | implementations]
    |> CSV.encode(separator: ?;)
    |> Enum.to_list()
  end

  defp export(headers, implementations, _acc) do
    empty = build_empty_list([], length(headers))
    list = [empty, empty, headers] ++ implementations

    list
    |> CSV.encode(separator: ?;)
    |> Enum.to_list()
  end

  defp build_headers(header_labels) do
    [
      "implementation_key",
      "implementation_type",
      "executable",
      "rule",
      "template",
      "goal",
      "minimum",
      "business_concept",
      "last_execution_at",
      "result",
      "execution",
      "inserted_at"
    ]
    |> Enum.map(fn h -> Map.get(header_labels, h, h) end)
  end

  defp get_content_field(_template, nil) do
    ""
  end

  defp get_content_field(%{"type" => "url", "name" => name}, content) do
    content
    |> Map.get(String.to_atom(name), [])
    |> content_to_list()
    |> Enum.map(&get_url_value/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.join(", ")
  end

  defp get_content_field(%{"type" => type, "name" => name}, content)
       when type in ["domain", "system"] do
    content
    |> Map.get(String.to_atom(name), [])
    |> content_to_list()
    |> Enum.map(&Map.get(&1, :name, ""))
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
    |> Map.get(String.to_atom(name), [])
    |> content_to_list()
    |> Enum.map(fn map_value ->
      Enum.find(values, fn %{"value" => value} -> value == map_value end)
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.map(&Map.get(&1, "text", ""))
    |> Enum.join(", ")
  end

  defp get_content_field(%{"type" => "table"}, _content), do: ""

  defp get_content_field(%{"name" => name}, content) do
    Map.get(content, String.to_atom(name), "")
  end

  defp get_url_value(%{url_value: url_value}), do: url_value
  defp get_url_value(_), do: nil

  defp content_to_list(nil), do: []

  defp content_to_list([""]), do: []

  defp content_to_list(""), do: []

  defp content_to_list(content) when is_list(content), do: content

  defp content_to_list(content), do: [content]

  defp build_empty_list(acc, l) when l < 1, do: acc
  defp build_empty_list(acc, l), do: ["" | build_empty_list(acc, l - 1)]

  defp translate(nil, _content_labels), do: nil

  defp translate(content, content_labels), do: Map.get(content_labels, content, content)
end
