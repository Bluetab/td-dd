defmodule TdDq.XLSX.Writer do
  @moduledoc """
  Writes necessary content information from data structures published and pending (non-published) to create
  a xlsx file.
  """

  alias TdCache.ConceptCache
  alias TdCache.I18nCache
  alias TdDfLib.Format
  alias TdDfLib.Parser
  alias TdDq.Implementations

  @headers [
    "implementation_key",
    "implementation_type",
    "domain_external_id",
    "domain",
    "executable",
    "rule",
    "rule_template",
    "implementation_template",
    "result_type",
    "goal",
    "minimum",
    "records",
    "errors",
    "result",
    "execution",
    "last_execution_at",
    "inserted_at",
    "updated_at",
    "business_concepts",
    "structure_domains",
    "rule_template_fields",
    "template_fields",
    "data_set_external_ids",
    "validation_fields",
    "result_details"
  ]

  @color_yellow "#ffd428"
  @color_ligth_yellow "#ffe994"

  def rows_by_implementation_template(implementation_information, opts \\ []) do
    Enum.into(implementation_information, %{}, fn {template_name, implementations} ->
      {rule_fields, rule_field_headers} =
        fields_with_headers(
          implementations,
          opts[:lang],
          &rule_template_content/1,
          nil
        )

      {imp_fields, imp_field_headers} =
        fields_with_headers(
          implementations,
          opts[:lang],
          &template_content/1,
          @color_ligth_yellow
        )

      result_details_fields =
        implementations
        |> result_headers(&result_content/1)
        |> Enum.sort()

      result_details_headers =
        Enum.map(result_details_fields, fn header -> "result_details_" <> header end)

      number_of_validations =
        count_implementations_items(implementations, "validations")

      number_of_datasets = count_implementations_items(implementations, "datasets")

      headers =
        headers_for_type(
          rule_field_headers,
          result_details_headers,
          imp_field_headers,
          number_of_datasets,
          number_of_validations,
          opts
        )

      parser_opts = [
        domain_type: :with_domain_external_id,
        lang: opts[:lang],
        xlsx: true,
        locales: I18nCache.get_active_locales!()
      ]

      parsing_contexts = prepare_parsing_context(rule_fields, imp_fields, parser_opts)

      opts =
        opts
        |> Keyword.put(:parsing_contexts, parsing_contexts)
        |> Keyword.put(:parser_opts, parser_opts)

      content =
        Enum.map(implementations, fn implementation ->
          implementation
          |> add_header_information(
            imp_fields,
            rule_fields,
            result_details_fields,
            number_of_datasets,
            number_of_validations,
            opts
          )
        end)

      rows = [headers | content]

      {template_name, rows}
    end)
  end

  defp headers_for_type(
         rule_field_headers,
         result_details_headers,
         content_headers,
         number_of_datasets,
         number_of_validations,
         opts
       ) do
    @headers
    |> Enum.flat_map(fn
      "implementation_key" ->
        [[get_translated_header("implementation_key", opts), bg_color: @color_yellow]]

      "domain_external_id" ->
        [[get_translated_header("domain_external_id", opts), bg_color: @color_yellow]]

      "domain" ->
        [[get_translated_header("domain", opts)]]

      "implementation_template" ->
        [[get_translated_header("implementation_template", opts), bg_color: @color_yellow]]

      "goal" ->
        [[get_translated_header("goal", opts), bg_color: @color_yellow]]

      "minimum" ->
        [[get_translated_header("minimum", opts), bg_color: @color_yellow]]

      "result_type" ->
        [[get_translated_header("result_type", opts), bg_color: @color_yellow]]

      "template_fields" ->
        content_headers

      "rule_template_fields" ->
        rule_field_headers

      "result_details" ->
        result_details_headers

      "data_set_external_ids" ->
        dynamic_headers(number_of_datasets, "datasets")

      "validation_fields" ->
        dynamic_headers(number_of_validations, "validations")

      header ->
        [[get_translated_header(header, opts)]]
    end)
  end

  defp add_header_information(
         implementation,
         content,
         rule_fields,
         result_details_fields,
         number_of_datasets,
         number_of_validations,
         opts
       ) do
    parsing_contexts = Keyword.get(opts, :parsing_contexts)
    parser_opts = Keyword.get(opts, :parser_opts)

    base_columns = [
      get_string_value(implementation, "implementation_key"),
      implementation["implementation_type"],
      get_domain_external_id(implementation),
      get_domain(implementation),
      get_translated_value(
        "ruleImplementation.props.executable.#{implementation["executable"]}",
        opts
      ),
      get_rule(implementation),
      get_rule_template(implementation),
      get_string_value(implementation, "df_name"),
      get_translated_value(
        "ruleImplementations.props.result_type.#{implementation["result_type"]}",
        opts
      ),
      get_string_value(implementation, "goal"),
      get_string_value(implementation, "minimum"),
      get_result_info(implementation, "records"),
      get_result_info(implementation, "errors"),
      get_result_info(implementation, "result"),
      get_result_info(implementation, "result_text", opts),
      get_result_info(implementation, "date", "datetime"),
      get_string_value(implementation, "inserted_at", "datetime"),
      get_string_value(implementation, "updated_at", "datetime"),
      get_concepts(implementation),
      get_structure_domains(implementation)
    ]

    rule_context = if parsing_contexts, do: parsing_contexts[:rule], else: nil
    template_context = if parsing_contexts, do: parsing_contexts[:template], else: nil

    rule_template_columns =
      add_content_columns(
        [],
        implementation,
        rule_fields,
        "rule",
        opts,
        rule_context,
        parser_opts
      )

    template_columns =
      add_content_columns(
        [],
        implementation,
        content,
        "template",
        opts,
        template_context,
        parser_opts
      )

    dataset_columns =
      fill_with(
        get_implementation_fields(implementation, "datasets"),
        number_of_datasets,
        ""
      )

    validation_columns =
      fill_with(
        get_implementation_fields(implementation, "validations"),
        number_of_validations,
        ""
      )

    result_detail_columns = get_result_details(implementation, result_details_fields)

    base_columns ++
      rule_template_columns ++
      template_columns ++
      dataset_columns ++
      validation_columns ++
      result_detail_columns
  end

  defp add_content_columns(
         fields,
         %{"df_content" => df_content},
         content,
         "template",
         opts,
         context,
         parser_opts
       ),
       do: add_content(fields, df_content, content, opts, context, parser_opts)

  defp add_content_columns(
         fields,
         %{"rule" => %{"df_content" => df_content}},
         content,
         "rule",
         opts,
         context,
         parser_opts
       ),
       do: add_content(fields, df_content, content, opts, context, parser_opts)

  defp add_content_columns(fields, _df_content, content, "rule", opts, _context, _parser_opts),
    do: add_empty_content(fields, content, opts)

  defp add_content(fields, df_content, content, opts, context, parser_opts)

  defp add_content(fields, df_content, content, _opts, context, parser_opts)
       when is_map(df_content) and is_list(content) do
    Parser.append_parsed_fields(fields, content, df_content, parser_opts, context)
  end

  defp add_content(fields, _headers, _data, _opts, _context, _parser_opts), do: fields

  defp add_empty_content(fields, content, _opts)
       when is_list(content),
       do: Enum.reduce(content, fields, fn _item, acc -> acc ++ [""] end)

  defp get_domain(%{"domain" => %{"name" => domain_name}}), do: domain_name

  defp get_domain_external_id(%{"domain" => %{"external_id" => domain_external_id_name}}),
    do: domain_external_id_name

  defp get_rule(implementation) do
    case(implementation) do
      %{"rule" => %{"name" => name}} when is_binary(name) -> name
      %{"rule" => %{"name" => name}} when is_integer(name) -> to_string(name)
      _ -> ""
    end
  end

  defp get_rule_template(implementation) do
    case(implementation) do
      %{"rule" => %{"df_name" => df_name}} when is_binary(df_name) -> df_name
      _ -> ""
    end
  end

  defp get_string_value(implementation, key) do
    case(Map.get(implementation, key)) do
      nil -> ""
      value when is_binary(value) -> value
      value -> to_string(value)
    end
  end

  ## REVIEW TD-7617: Hay que cambiar el datetime a string????
  defp get_string_value(implementation, key, "datetime") do
    case(Map.get(implementation, key)) do
      nil -> ""
      value -> TdDd.Helpers.shift_zone(value)
    end
  end

  defp format_datetime(datetime) do
    datetime
    |> DateTime.from_naive!("Etc/UTC")
    |> Calendar.strftime("%Y-%m-%d %H:%M:%S")
  rescue
    _ -> to_string(datetime)
  end

  defp get_concepts(implementation) do
    case(implementation) do
      %{"concepts" => concepts} when is_list(concepts) and concepts != [] ->
        get_concepts_from_list(concepts)

      %{"concepts" => concept_id} when is_integer(concept_id) ->
        get_concept_name(concept_id)

      _ ->
        ""
    end
  end

  defp get_concepts_from_list(concepts),
    do:
      concepts
      |> Enum.map(&get_concept_name/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.sort()
      |> Enum.join(" | ")

  defp get_concept_name(id) do
    case ConceptCache.get(id) do
      {:ok, %{name: name}} when is_binary(name) -> name
      _ -> ""
    end
  end

  defp get_structure_domains(implementation) do
    case(implementation) do
      %{"structure_domains" => domains} when is_list(domains) and domains != [] ->
        domains
        |> Enum.map(fn
          %{"name" => name} when is_binary(name) -> name
          _ -> ""
        end)
        |> Enum.reject(&(&1 == ""))
        |> Enum.sort()
        |> Enum.join(" | ")

      _ ->
        ""
    end
  end

  defp get_translated_header(value, opts) do
    case I18nCache.get_definition(opts[:lang], "ruleImplementations.props.#{value}",
           default_value: value
         ) do
      text when is_binary(text) -> text
      _ -> value
    end
  end

  defp get_translated_value(value, opts) do
    case I18nCache.get_definition(opts[:lang], value, default_value: value) do
      text when is_binary(text) -> text
      _ -> value
    end
  end

  defp get_result_info(implementation, key) do
    case(implementation) do
      %{"execution_result_info" => %{^key => value}} ->
        case value do
          nil -> ""
          %DateTime{} = datetime -> format_datetime(datetime)
          %NaiveDateTime{} = datetime -> format_datetime(datetime)
          value when is_binary(value) -> value
          value -> to_string(value)
        end

      _ ->
        ""
    end
  end

  defp get_result_info(implementation, key, opts) do
    case(implementation) do
      %{"execution_result_info" => %{^key => result_text}} when opts == "datetime" ->
        TdDd.Helpers.shift_zone(result_text)

      %{"execution_result_info" => %{^key => result_text}} when is_binary(result_text) ->
        get_translated_value(result_text, opts)

      _ ->
        ""
    end
  end

  defp get_result_details(implementation, headers) do
    case implementation do
      %{"execution_result_info" => %{"details" => result_details}}
      when is_list(result_details) or is_map(result_details) ->
        process_result_details(result_details, headers)

      _ ->
        [""]
    end
  end

  defp process_result_details(result_details, headers) do
    Enum.map(headers, fn
      "Query" = header ->
        Base.decode64!(Map.get(result_details, header, ""))

      "base64_QueryEvidences" = header ->
        Base.decode64!(Map.get(result_details, header, ""))

      header ->
        data = Map.get(result_details, header, nil)

        if is_map(data) do
          Jason.encode!(data)
        else
          data
        end
    end)
  end

  defp rule_template_content(%{"rule" => %{"template" => %{content: content}}}), do: content
  defp rule_template_content(_), do: nil

  defp template_content(%{"template" => %{content: content}}), do: content

  defp template_content(_), do: nil

  defp result_content(%{"execution_result_info" => %{"details" => %{} = details}}), do: details
  defp result_content(_), do: nil

  defp fields_with_headers(records, lang, fun, nil),
    do:
      records
      |> Enum.group_by(fun)
      |> Map.delete(nil)
      |> Map.keys()
      |> Enum.flat_map(&Format.flatten_content_fields(&1, lang))
      |> Enum.uniq()
      |> Enum.map(&{Map.take(&1, ["name", "values", "type", "label"]), Map.get(&1, "definition")})
      |> Enum.unzip()

  defp fields_with_headers(records, lang, fun, color),
    do:
      records
      |> Enum.group_by(fun)
      |> Map.delete(nil)
      |> Map.keys()
      |> Enum.flat_map(&Format.flatten_content_fields(&1, lang))
      |> Enum.uniq()
      |> Enum.map(
        &{Map.take(&1, ["name", "values", "type", "label"]),
         [
           Map.get(&1, "definition"),
           bg_color: color
         ]}
      )
      |> Enum.unzip()

  defp result_headers(records, fun),
    do:
      records
      |> Enum.group_by(fun)
      |> Map.delete(nil)
      |> Map.keys()
      |> Enum.flat_map(fn tuple -> Map.keys(tuple) end)
      |> Enum.uniq()

  defp dynamic_headers(0, _items_key), do: [[""]]

  defp dynamic_headers(number_of_items, items_key) do
    prefix =
      case items_key do
        "validations" -> "validation_field_"
        "datasets" -> "dataset_external_id_"
      end

    Enum.concat(1..number_of_items |> Enum.map(&["#{prefix}#{&1}"]))
  end

  defp count_implementations_items(implementations, items),
    do:
      Enum.reduce(implementations, 0, fn implementation, acc ->
        implementation
        |> get_implementation_fields(items)
        |> Enum.uniq()
        |> Enum.count()
        |> max(acc)
      end)

  defp fill_with(list, size, item) do
    case(size - Enum.count(list)) do
      len when len <= 0 -> list
      len -> list ++ List.duplicate(item, len)
    end
  end

  defp get_implementation_fields(%{"dataset" => dataset} = _implementation, "datasets"),
    do:
      dataset
      |> Enum.map(fn
        %{"structure" => %{"external_id" => external_id}} ->
          external_id

        %{"structure" => %{"name" => name, "type" => "reference_dataset"}} ->
          "reference_dataset:/#{name}"

        %{"structure" => %{"id" => id, "name" => nil, "type" => nil}} ->
          "dataset_structure_id:/#{id}"
      end)
      |> Enum.uniq()

  defp get_implementation_fields(
         %{"validation" => [%{"conditions" => [%{} | _]} | _] = validations} = _implementation,
         "validations"
       ),
       do:
         validations
         |> Implementations.flatten_conditions_set()
         |> Enum.map(fn
           %{"structure" => %{"external_id" => external_id}} ->
             external_id

           %{"structure" => %{"name" => name, "type" => "reference_dataset_field"}} ->
             "reference_dataset_field:/#{name}"

           %{"structure" => %{"id" => id, "name" => nil, "type" => nil}} ->
             "validation_structure_id:/#{id}"
         end)
         |> Enum.uniq()

  defp get_implementation_fields(_, _), do: []

  defp prepare_parsing_context(rule_fields, template_fields, opts) do
    domain_type = Keyword.get(opts, :domain_type, :with_domain_external_id)
    lang = Keyword.get(opts, :lang)

    rule_ctx =
      rule_fields
      |> Parser.context_for_fields(domain_type)
      |> Map.put("lang", lang)

    template_ctx =
      template_fields
      |> Parser.context_for_fields(domain_type)
      |> Map.put("lang", lang)

    %{rule: rule_ctx, template: template_ctx}
  end
end
