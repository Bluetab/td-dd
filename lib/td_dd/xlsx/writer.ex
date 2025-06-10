defmodule TdDd.XLSX.Writer do
  @moduledoc """
  Writes necessary content information from data structures published and pending (non-published) to create
  a xlsx file.
  """
  alias TdCache.DomainCache
  alias TdDd.DataStructures.DataStructureTypes
  alias TdDfLib.Parser

  @headers [
    "type",
    "name",
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
    "external_id",
    "name",
    "tech_name",
    "alias_name",
    "link_to_structure",
    "domain",
    "type",
    "system",
    "path"
  ]

  @grant_headers [
    "user_name",
    "data_structure_name",
    "domain_name",
    "system_name",
    "structure_path",
    "start_date",
    "end_date",
    "grant_details"
  ]

  def data_structure_type_information(structures, opts \\ []) do
    structures
    |> Enum.group_by(& &1.type)
    |> Enum.into(%{}, fn {type, grouped_structures} ->
      %{name: data_structure_type, template: template} = DataStructureTypes.get_by(name: type)

      structure_type_information =
        add_information_for_download_type(
          %{structures: grouped_structures},
          template,
          opts[:download_type]
        )

      {data_structure_type, structure_type_information}
    end)
  end

  def rows_by_structure_type(type_information, structure_url_schema, opts \\ []) do
    Enum.into(type_information, %{}, fn {data_structure_type, information} ->
      headers = headers_for_type(information, opts)
      content = content_for_type(information, structure_url_schema, opts)
      rows = [headers | content]

      {data_structure_type, rows}
    end)
  end

  def grant_rows(grants, header_labels \\ nil) do
    headers = build_grant_headers(header_labels, @grant_headers)
    grant_list = grants_to_list(grants)

    [headers | grant_list]
  end

  defp add_information_for_download_type(type_information, template, :editable) do
    case template do
      %{content: content} ->
        flat_fields =
          Enum.flat_map(content, fn %{"fields" => fields} ->
            Enum.uniq_by(fields, & &1["name"])
          end)

        Map.put(type_information, :content, flat_fields)

      _ ->
        Map.put(type_information, :content, [])
    end
  end

  defp add_information_for_download_type(
         %{structures: structures} = structure_type_information,
         _template,
         nil
       ) do
    Map.put(structure_type_information, :metadata, metadata_fields(structures))
  end

  defp metadata_fields(structures) do
    structures
    |> Enum.reduce(MapSet.new(), fn
      %{metadata: %{} = metadata}, acc ->
        metadata
        |> Map.keys()
        |> MapSet.new(fn key -> "metadata:" <> key end)
        |> MapSet.union(acc)

      _structure, acc ->
        acc
    end)
    |> MapSet.to_list()
  end

  defp headers_for_type(information, opts) do
    case opts[:download_type] do
      :editable ->
        content_headers =
          information
          |> Map.get(:content)
          |> Enum.map(&[Map.get(&1, "name"), bg_color: "#ffe994"])

        highlight(@editable_headers) ++ content_headers

      _ ->
        header_labels = opts[:header_labels]

        metadata_headers =
          information
          |> Map.get(:metadata)
          |> with_header_labels(header_labels)

        with_header_labels(@headers, header_labels) ++ metadata_headers
    end
  end

  defp content_for_type(
         %{structures: structures} = type_information,
         structure_url_schema,
         opts
       ) do
    Enum.map(structures, fn structure ->
      structure
      |> add_header_information(structure_url_schema, opts)
      |> add_content_or_metadata(type_information, structure, opts)
    end)
  end

  defp add_header_information(structure, structure_url_schema, opts) do
    opts[:download_type]
    |> fetch_headers()
    |> Enum.map(fn
      "path" -> transform_path(structure)
      "system" -> structure.system["name"]
      "domain" -> get_domain(structure)
      "tech_name" -> get_tech_name(structure)
      "alias_name" -> get_alias_name(structure)
      "link_to_structure" -> get_link_to_structure(structure, structure_url_schema)
      other when is_binary(other) -> Map.get(structure, String.to_existing_atom(other))
    end)
  end

  defp add_content_or_metadata(fields, %{content: [_ | _] = content_fields}, note_info, opts) do
    note =
      case opts[:note_type] do
        :published -> note_info[:note]
        :non_published -> note_info[:non_published_note]["note"]
      end

    parser_opts = [
      domain_type: :with_domain_external_id,
      lang: opts[:lang],
      xlsx: true
    ]

    Parser.append_parsed_fields(fields, content_fields, note, parser_opts)
  end

  defp add_content_or_metadata(
         fields,
         %{metadata: [_ | _] = metadata_fields},
         %{
           metadata: metadata
         },
         _opts
       )
       when is_map(metadata) do
    fields ++
      Enum.map(metadata_fields, fn "metadata:" <> suffix ->
        metadata
        |> Map.get(suffix, "")
        |> parse_metadata()
      end)
  end

  defp add_content_or_metadata(fields, _content_fields, _structure, _opts), do: fields

  defp highlight(headers) do
    Enum.map(headers, fn
      "external_id" -> ["external_id", bg_color: "#ffd428"]
      header -> header
    end)
  end

  defp with_header_labels(headers, %{} = header_labels) do
    Enum.map(headers, fn
      "metadata:" <> suffix ->
        Map.get(header_labels, "metadata", "metadata") <> ":#{suffix}"

      field ->
        Map.get(header_labels, field, field)
    end)
  end

  defp with_header_labels(headers, _header_labels), do: headers

  defp fetch_headers(:editable), do: @editable_headers
  defp fetch_headers(_download_type), do: @headers

  defp transform_path(%{path: path}), do: Enum.join(path, " > ")

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

  defp get_tech_name(structure) do
    Map.get(structure, :original_name) || structure.name
  end

  defp get_alias_name(structure) do
    case structure do
      %{note: %{"alias" => alias_value}} when is_binary(alias_value) ->
        alias_value

      %{note: %{"alias" => %{"value" => alias_value}}} ->
        alias_value

      %{non_published_note: %{"note" => %{"alias" => alias_value}}} when is_binary(alias_value) ->
        alias_value

      %{non_published_note: %{"note" => %{"alias" => %{"value" => alias_value}}}} ->
        alias_value

      _ ->
        ""
    end
  end

  defp get_link_to_structure(structure, structure_url_schema)
       when is_binary(structure_url_schema) do
    if String.contains?(structure_url_schema, "/:id") do
      String.replace(structure_url_schema, ":id", to_string(structure.data_structure_id))
    else
      ""
    end
  end

  defp get_link_to_structure(_structure, _url_schema), do: ""

  defp parse_metadata(metadata) when is_binary(metadata), do: metadata

  defp parse_metadata(metadata) when is_list(metadata) or is_map(metadata) do
    Jason.encode!(metadata)
  end

  defp parse_metadata(nil), do: ""

  defp parse_metadata(metadata), do: metadata

  defp build_grant_headers(nil, headers) do
    headers
  end

  defp build_grant_headers(header_labels, headers) do
    Enum.map(headers, fn h -> Map.get(header_labels, h, h) end)
  end

  defp grants_to_list(grants) do
    Enum.map(
      grants,
      fn grant ->
        [
          get_in(grant, [:user, :full_name]),
          get_in(grant, [:data_structure_version, :name]),
          get_domain(grant.data_structure_version),
          get_in(grant, [:data_structure_version, :system, :name]),
          transform_path(grant.data_structure_version),
          grant.start_date,
          grant.end_date,
          Jason.encode!(grant.detail)
        ]
      end
    )
  end
end
