defmodule TdDdWeb.MetadataController do
  require Logger
  use TdDdWeb, :controller

  alias Plug.Upload
  alias TdDd.Auth.Guardian.Plug, as: GuardianPlug
  alias TdDd.DataStructures
  alias TdDd.Loader
  alias TdPerms.TaxonomyCache

  @data_structure_keys Application.get_env(:td_dd, :metadata)[:data_structure_keys]
  @data_field_keys Application.get_env(:td_dd, :metadata)[:data_field_keys]
  @data_structure_relation_keys Application.get_env(:td_dd, :metadata)[
                                  :data_structure_relation_keys
                                ]
  @data_structure_modifiable_fields Application.get_env(:td_dd, :metadata)[
                                      :data_structure_modifiable_fields
                                    ]
  @data_field_modifiable_fields Application.get_env(:td_dd, :metadata)[
                                  :data_field_modifiable_fields
                                ]

  @data_fields_not_blank ["ou", "description"]

  @doc """
    Upload metadata:

      data_structures.csv: system, group, name, description
      data_fields.csv: system, group, name, field name, type, descripiton, nullable, precision, business_concept_id

      curl -H "Content-Type: application/json" -X POST -d '{"user":{"user_name":"xxx","password":"xxx"}}' http://localhost:4001/api/sessions
      curl -H "authorization: Bearer xxx" -F "data_structures=@data_structures.csv" -F "data_fields=@data_fields.csv"  http://localhost:4005/api/td_dd/metadata

  """
  def upload(conn, params) do
    do_upload(conn, params)
    send_resp(conn, :no_content, "")
  rescue
    e in RuntimeError ->
      Logger.error("While uploading #{e.message}")
      send_resp(conn, :unprocessable_entity, Poison.encode!(%{error: e.message}))
  end

  defp do_upload(conn, params) do
    Logger.info("Uploading metadata...")

    start_time = DateTime.utc_now()

    structure_recs = params |> Map.get("data_structures") |> parse_data_structures
    field_recs = params |> Map.get("data_fields") |> parse_data_fields

    relation_recs =
      params |> Map.get("data_structure_relations") |> parse_data_structure_relations

    load(conn, structure_recs, field_recs, relation_recs)

    end_time = DateTime.utc_now()

    Logger.info("Metadata uploaded. Elapsed seconds: #{DateTime.diff(end_time, start_time)}")
  end

  defp parse_data_structures(%Upload{path: path}) do
    domain_map = TaxonomyCache.get_domain_name_to_id_map()

    path
    |> File.stream!()
    |> CSV.decode!(separator: ?;, headers: true)
    |> Enum.map(&csv_to_structure(&1, domain_map))
  end

  defp parse_data_fields(%Upload{path: path}) do
    path
    |> File.stream!()
    |> CSV.decode!(separator: ?;, headers: true)
    |> Enum.map(&csv_to_field/1)
  end

  defp parse_data_fields(nil), do: []

  defp parse_data_structure_relations(%Upload{path: path}) do
    path
    |> File.stream!()
    |> CSV.decode!(separator: ?;, headers: true)
    |> Enum.map(&csv_to_relation/1)
  end

  defp parse_data_structure_relations(nil), do: []

  defp load(conn, structure_records, field_records, relation_records) do
    user_id = GuardianPlug.current_resource(conn).id
    audit_fields = %{last_change_at: DateTime.utc_now(), last_change_by: user_id}
    Loader.load(structure_records, field_records, relation_records, audit_fields)
  end

  defp csv_to_structure(record, domain_map) do
    record
    |> blank_to_nil(@data_fields_not_blank)
    |> add_metadata(@data_structure_modifiable_fields)
    |> DataStructures.add_domain_id(domain_map)
    |> to_map(@data_structure_keys)
  end

  defp csv_to_field(record) do
    record
    |> add_metadata(@data_field_modifiable_fields)
    |> to_map(@data_field_keys)
  end

  defp csv_to_relation(record) do
    record
    |> to_map(@data_structure_relation_keys)
  end

  defp to_map(data, keys) do
    keys
    |> Enum.map(fn key -> {key, get_value(data, key)} end)
    |> Map.new(fn {k, v} -> {String.to_atom(k), v} end)
  end

  defp blank_to_nil(data, [head | tail]) do
    data
    |> blank_to_nil(head)
    |> blank_to_nil(tail)
  end

  defp blank_to_nil(data, []), do: data

  defp blank_to_nil(data, field_name) do
    value = Map.fetch!(data, field_name)

    case value do
      "" -> Map.put(data, field_name, nil)
      _ -> data
    end
  end

  defp get_value(data, "nullable" = name) do
    case String.downcase(Map.get(data, name)) do
      "" -> nil
      value -> Enum.member?(["t", "true", "y", "yes", "on", "1"], value)
    end
  end

  defp get_value(data, "version" = name), do: get_version(data, name)

  defp get_value(data, name), do: Map.get(data, name)

  defp get_version(data, name) do
    case Map.get(data, name) do
      # TODO: Use nil instead of 0, automatically version in loader.ex
      nil -> 0
      "" -> 0
      value -> String.to_integer(value)
    end
  end

  defp add_metadata(data, fields) do
    metadata =
      fields
      |> Enum.reduce(%{}, &Map.put(&2, &1, Map.get(data, &1)))

    Map.put(data, "metadata", metadata)
  end
end
