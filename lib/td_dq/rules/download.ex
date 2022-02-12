defmodule TdDq.Implementations.Download do
  @moduledoc """
  Helper module to download implementations.
  """

  alias TdCache.TemplateCache
  alias TdDfLib.Format

  @spec to_csv(any, any, any) :: binary
  def to_csv([], _, _), do: ""

  def to_csv(implementations, header_labels, content_labels) do
    rule_types = Enum.map(implementations, &get_rule_types(&1)) |> List.flatten() |> Enum.uniq()

    implementation_types =
      Enum.map(implementations, &get_implementation_types(&1)) |> List.flatten() |> Enum.uniq()

    templates = [
      List.flatten(
        Map.values(Enum.reduce(rule_types, %{}, &Map.put(&2, &1, TemplateCache.get_by_name!(&1))))
      ),
      List.flatten(
        Map.values(
          Enum.reduce(implementation_types, %{}, &Map.put(&2, &1, TemplateCache.get_by_name!(&1)))
        )
      )
    ]

    build_csv(implementations, templates, header_labels, content_labels)
  end

  defp get_rule_types(implementation) do
    implementation
    |> Map.get(:rule)
    |> Map.get(:df_name)
  end

  defp get_implementation_types(implementation) do
    implementation
    |> Map.get(:df_name)
  end

  defp build_csv(implementations, templates, header_labels, content_labels) do
    templates
    |> csv_format(implementations, header_labels, content_labels)
    |> to_string()
  end

  defp csv_format(
         [rule_templates, implementation_templates],
         implementations,
         header_labels,
         content_labels
       ) do
    [rule_fields, rule_field_headers] = get_template_info(rule_templates)

    [implementation_fields, implementation_field_headers] =
      get_template_info(implementation_templates)

    headers =
      header_labels
      |> build_headers()
      |> concat_headers(implementations, :datasets)
      |> concat_headers(implementations, :validations)

    headers = headers ++ rule_field_headers ++ implementation_field_headers

    implementations =
      format_implementations(content_labels, implementations, [rule_fields, implementation_fields])

    export(headers, implementations)
  end

  defp get_template_info(templates) do
    content =
      templates
      |> Enum.filter(fn template -> template != nil end)
      |> Enum.map(fn template -> Format.flatten_content_fields(template.content) end)
      |> List.flatten()
      |> Enum.uniq()

    fields = Enum.reduce(content, [], &(&2 ++ [Map.take(&1, ["name", "values", "type"])]))

    field_headers = Enum.reduce(content, [], &(&2 ++ [Map.get(&1, "label")]))

    [fields, field_headers]
  end

  defp format_implementations(content_labels, implementations, [
         rule_fields,
         implementation_fields
       ]) do
    number_of_dataset_external_ids = count_implementations_items(implementations, :datasets)
    number_of_validations_fields = count_implementations_items(implementations, :validations)

    Enum.reduce(implementations, [], fn implementation, acc ->
      rule = Map.get(implementation, :rule)
      rule_content = Map.get(rule, :df_content)
      implementation_content = Map.get(implementation, :df_content)

      values =
        [
          implementation.implementation_key,
          implementation.implementation_type,
          translate("executable.#{implementation.executable}", content_labels),
          rule.name,
          rule.df_name,
          Map.get(implementation, :df_name),
          implementation.goal,
          implementation.minimum,
          get_in(implementation, [:current_business_concept_version, :name]),
          get_in(implementation, [:execution_result_info, :date])
          |> TdDd.Helpers.shift_zone(),
          get_in(implementation, [:execution_result_info, :records]),
          get_in(implementation, [:execution_result_info, :errors]),
          get_in(implementation, [:execution_result_info, :result]),
          implementation
          |> get_in([:execution_result_info, :result_text])
          |> translate(content_labels),
          implementation.inserted_at
        ] ++
          fill_with(
            get_implementation_fields(implementation, :datasets),
            number_of_dataset_external_ids,
            nil
          ) ++
          fill_with(
            get_implementation_fields(implementation, :validations),
            number_of_validations_fields,
            nil
          )

      values_with_rule_content =
        Enum.reduce(rule_fields, values, &(&2 ++ [get_content_field(&1, rule_content)]))

      values_with_rule_and_implementation_content =
        Enum.reduce(
          implementation_fields,
          values_with_rule_content,
          &(&2 ++ [get_content_field(&1, implementation_content)])
        )

      acc ++ [values_with_rule_and_implementation_content]
    end)
  end



  defp export(headers, implementations) do
    [headers | implementations]
    |> CSV.encode(separator: ?;)
    |> Enum.to_list()
  end

  defp build_headers(header_labels) do
    [
      "implementation_key",
      "implementation_type",
      "executable",
      "rule",
      "rule_template",
      "implementation_template",
      "goal",
      "minimum",
      "business_concept",
      "last_execution_at",
      "records",
      "errors",
      "result",
      "execution",
      "inserted_at"
    ]
    |> Enum.map(fn h -> Map.get(header_labels, h, h) end)
  end

  defp concat_headers(header_labels, implementations, items_key) do
    prefix =
      case items_key do
        :validations -> "validation_field_"
        :datasets -> "dataset_external_id_"
      end

    case count_implementations_items(implementations, items_key) do
      0 ->
        header_labels

      items ->
        Enum.concat(
          header_labels,
          1..items |> Enum.map(&"#{prefix}#{&1}")
        )
    end
  end

  defp count_implementations_items(implementations, items) do
    Enum.reduce(implementations, 0, fn implementation, acc ->
      implementation
      |> get_implementation_fields(items)
      |> Enum.uniq()
      |> Enum.count()
      |> max(acc)
    end)
  end

  defp get_implementation_fields(%{dataset: dataset} = _implementation, :datasets) do
    Enum.map(dataset, fn %{structure: %{external_id: external_id}} -> external_id end)
  end

  defp get_implementation_fields(%{validations: validations} = _implementation, :validations) do
    Enum.map(validations, fn %{structure: %{external_id: external_id}} -> external_id end)
  end

  defp get_implementation_fields(_, _), do: []

  defp fill_with(list, size, item) do
    case size - Enum.count(list) do
      len when len <= 0 -> list
      len -> list ++ List.duplicate(item, len)
    end
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

  defp get_content_field(%{"name" => "tags"}, %{tags: tags}) when is_list(tags) do
    Enum.join(tags, ", ")
  end

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

  defp translate(nil, _content_labels), do: nil

  defp translate(content, content_labels), do: Map.get(content_labels, content, content)
end
