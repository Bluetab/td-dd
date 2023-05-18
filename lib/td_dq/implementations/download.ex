defmodule TdDq.Implementations.Download do
  @moduledoc """
  Helper module to download implementations.
  """

  alias TdCache.DomainCache
  alias TdCache.TemplateCache
  alias TdDfLib.Format
  alias TdDfLib.Parser
  alias TdDq.Implementations

  def to_csv([], _, _), do: ""

  def to_csv(implementations, header_labels, content_labels) do
    implementations
    |> enrich_templates()
    |> csv_format(header_labels, content_labels)
    |> to_string()
  end

  defp csv_format(implementations, header_labels, content_labels) do
    {rule_fields, rule_field_headers} =
      fields_with_headers(implementations, &rule_template_content/1)

    {implementation_fields, implementation_field_headers} =
      fields_with_headers(implementations, &template_content/1)

    result_details_headers = result_headers(implementations, &result_content/1)

    headers =
      header_labels
      |> build_headers()
      |> Kernel.++(
        Enum.map(result_details_headers, fn header ->
          "result_details_" <> Atom.to_string(header)
        end)
      )
      |> concat_headers(implementations, :datasets)
      |> concat_headers(implementations, :validations)

    headers = headers ++ rule_field_headers ++ implementation_field_headers

    implementations =
      format_implementations(
        content_labels,
        implementations,
        rule_fields,
        implementation_fields,
        result_details_headers
      )

    export(headers, implementations)
  end

  defp result_headers(records, fun) do
    records
    |> Enum.group_by(fun)
    |> Map.delete(nil)
    |> Map.keys()
    |> Enum.flat_map(fn tuple -> Map.keys(tuple) end)
    |> Enum.uniq()
  end

  defp fields_with_headers(records, fun) do
    records
    |> Enum.group_by(fun)
    |> Map.delete(nil)
    |> Map.keys()
    |> Enum.flat_map(&Format.flatten_content_fields/1)
    |> Enum.uniq()
    |> Enum.map(&{Map.take(&1, ["name", "values", "type"]), Map.get(&1, "label")})
    |> Enum.unzip()
  end

  defp format_implementations(
         content_labels,
         implementations,
         rule_fields,
         implementation_fields,
         result_details_headers
       ) do
    number_of_dataset_external_ids = count_implementations_items(implementations, :datasets)
    number_of_validations_fields = count_implementations_items(implementations, :validations)
    time_zone = Application.get_env(:td_dd, :time_zone)

    Enum.map(implementations, fn implementation ->
      rule = Map.get(implementation, :rule, %{})
      rule_content = Map.get(rule, :df_content, %{})
      implementation_content = Map.get(implementation, :df_content)

      ([
         implementation.implementation_key,
         implementation.implementation_type,
         get_domain(implementation.domain_ids),
         translate("executable.#{implementation.executable}", content_labels),
         Map.get(rule, :name, ""),
         Map.get(rule, :df_name, ""),
         implementation.df_name,
         implementation.goal,
         implementation.minimum,
         get_in(implementation, [:current_business_concept_version, :name]),
         get_in(implementation, [:execution_result_info, :date])
         |> TdDd.Helpers.shift_zone(time_zone),
         get_in(implementation, [:execution_result_info, :records]),
         get_in(implementation, [:execution_result_info, :errors]),
         get_in(implementation, [:execution_result_info, :result]),
         get_in(implementation, [:execution_result_info, :result_text])
         |> translate(content_labels),
         TdDd.Helpers.shift_zone(implementation.inserted_at, time_zone),
         get_domain(implementation.structure_domain_ids)
       ] ++
         fill_result_details(implementation, result_details_headers) ++
         fill_with(
           get_implementation_fields(implementation, :datasets),
           number_of_dataset_external_ids,
           nil
         ) ++
         fill_with(
           get_implementation_fields(implementation, :validations),
           number_of_validations_fields,
           nil
         ))
      |> Parser.append_parsed_fields(rule_fields, rule_content)
      |> Parser.append_parsed_fields(implementation_fields, implementation_content)
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
      "domain",
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
      "inserted_at",
      "structure_domains"
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
    dataset
    |> Enum.map(fn
      %{structure: %{external_id: external_id}} -> external_id
      %{structure: %{name: name, type: "reference_dataset"}} -> "reference_dataset:/#{name}"
    end)
    |> Enum.uniq()
  end

  defp get_implementation_fields(
         %{validation: [%{conditions: [%{} | _]} | _] = validations} = _implementation,
         :validations
       ) do
    validations
    |> Implementations.flatten_conditions_set()
    |> Enum.map(fn
      %{structure: %{external_id: external_id}} ->
        external_id

      %{structure: %{name: name, type: "reference_dataset_field"}} ->
        "reference_dataset_field:/#{name}"
    end)
    |> Enum.uniq()
  end

  defp get_implementation_fields(_, _), do: []

  defp fill_with(list, size, item) do
    case size - Enum.count(list) do
      len when len <= 0 -> list
      len -> list ++ List.duplicate(item, len)
    end
  end

  defp fill_result_details(%{execution_result_info: %{details: %{} = details}}, headers) do
    Enum.map(headers, fn
      :Query = header ->
        Base.decode64!(Map.get(details, header, ""))

      header ->
        data = Map.get(details, header, nil)

        if is_map(data) do
          Jason.encode!(data)
        else
          data
        end
    end)
  end

  defp fill_result_details(_, headers) do
    Enum.map(headers, fn _ ->
      nil
    end)
  end

  defp translate(nil, _content_labels), do: nil

  defp translate(content, content_labels), do: Map.get(content_labels, content, content)

  defp enrich_templates(implementations) do
    implementations
    |> Enum.group_by(&rule_type/1)
    |> Enum.flat_map(&enrich_rule_templates/1)
    |> Enum.group_by(&implementation_type/1)
    |> Enum.flat_map(&enrich_implementation_templates/1)
  end

  defp enrich_rule_templates({nil, implementations}), do: implementations

  defp enrich_rule_templates({type, implementations}) when is_binary(type) do
    template = TemplateCache.get_by_name!(type)
    enrich_rule_templates({template, implementations})
  end

  defp enrich_rule_templates({%{} = template, implementations}) do
    Enum.map(implementations, fn %{rule: rule} = implementation ->
      %{implementation | rule: Map.put(rule, :template, template)}
    end)
  end

  defp enrich_implementation_templates({nil, implementations}), do: implementations

  defp enrich_implementation_templates({type, implementations}) when is_binary(type) do
    template = TemplateCache.get_by_name!(type)
    enrich_implementation_templates({template, implementations})
  end

  defp enrich_implementation_templates({%{} = template, implementations}) do
    Enum.map(implementations, &Map.put(&1, :template, template))
  end

  defp rule_type(%{rule: %{df_name: rule_type}}), do: rule_type
  defp rule_type(_), do: nil

  defp implementation_type(%{df_name: implementation_type}), do: implementation_type
  defp implementation_type(_), do: nil

  defp rule_template_content(%{rule: %{template: %{content: content}}}), do: content
  defp rule_template_content(_), do: nil

  defp template_content(%{template: %{content: content}}), do: content
  defp template_content(_), do: nil

  defp result_content(%{execution_result_info: %{details: %{} = details}}), do: details
  defp result_content(_), do: nil

  defp get_domain([_ | _] = domain_ids) do
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
