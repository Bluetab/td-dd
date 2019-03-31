defmodule TdDdWeb.MetadataController do
  require Logger
  use TdDdWeb, :controller

  alias Plug.Upload
  alias TdDd.Auth.Guardian.Plug, as: GuardianPlug
  alias TdDd.CSV.Reader
  alias TdDd.Loader

  @index_worker Application.get_env(:td_dd, :index_worker)
  @taxonomy_cache Application.get_env(:td_dd, :taxonomy_cache)

  @structure_import_schema Application.get_env(:td_dd, :metadata)[:structure_import_schema]
  @structure_import_required Application.get_env(:td_dd, :metadata)[:structure_import_required]
  @field_import_schema Application.get_env(:td_dd, :metadata)[:field_import_schema]
  @field_import_required Application.get_env(:td_dd, :metadata)[:field_import_required]
  @relation_import_schema Application.get_env(:td_dd, :metadata)[:relation_import_schema]
  @relation_import_required Application.get_env(:td_dd, :metadata)[:relation_import_required]

  @doc """
    Upload metadata:

      data_structures.csv: 
          name: :string required structure name
          system: :string required system name
          group: :string required group name
          type: :string required structure type
          description: :string optional structure description
          external_id: :string optional structure external id (unique within system)
          ou: :string optional domain name
          version: :integer optional version (defaults to 0)
          metadata: :map (headers prefixed with "m:", e.g. "m:data_type" will be loaded into this map)
      data_fields.csv:
          name: :string required structure name
          system: :string required system name
          group: :string required group name
          external_id: :string optional external id of parent structure
          field_name: :string required field name
          description: :string optional field description
          business_concept_id: :string optional business concept id
          nullable: :boolean optional field nullability
          precision: :string optional field precision
          type: :string optional field type
          version: :integer optional structure version (defaults to 0)
          metadata: :map (headers prefixed with "m:", e.g. "m:data_type" will be loaded into this map)
      data_structure_relations.csv:
          system: :string required system name
          parent_group: :string required group name of parent
          parent_external_id: :string optional external id of parent
          parent_name: :string optional name of parent (required if parent_external_id is absent)
          child_group: :string required group name of child
          child_external_id: :string optional external id of child
          child_name: :string optional name of child (required if child_external_id is absent)

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

    {:ok, field_recs} = params |> Map.get("data_fields") |> parse_data_fields
    {:ok, structure_recs} = params |> Map.get("data_structures") |> parse_data_structures

    {:ok, relation_recs} =
      params |> Map.get("data_structure_relations") |> parse_data_structure_relations

    load(conn, structure_recs, field_recs, relation_recs)

    end_time = DateTime.utc_now()

    Logger.info("Metadata uploaded. Elapsed seconds: #{DateTime.diff(end_time, start_time)}")

    @index_worker.reindex()
  end

  defp parse_data_structures(%Upload{path: path}) do
    domain_map = @taxonomy_cache.get_domain_name_to_id_map()
    defaults = %{version: 0}

    path
    |> File.stream!()
    |> Reader.read_csv(
      domain_map: domain_map,
      defaults: defaults,
      schema: @structure_import_schema,
      required: @structure_import_required
    )
  end

  defp parse_data_structures(nil), do: {:ok, []}

  defp parse_data_fields(%Upload{path: path}) do
    defaults = %{version: 0, external_id: nil}

    path
    |> File.stream!()
    |> Reader.read_csv(
      defaults: defaults,
      schema: @field_import_schema,
      required: @field_import_required,
      booleans: ["nullable"]
    )
  end

  defp parse_data_fields(nil), do: {:ok, []}

  defp parse_data_structure_relations(%Upload{path: path}) do
    path
    |> File.stream!()
    |> Reader.read_csv(
      schema: @relation_import_schema,
      required: @relation_import_required
    )
  end

  defp parse_data_structure_relations(nil), do: {:ok, []}

  defp load(conn, structure_records, field_records, relation_records) do
    user_id = GuardianPlug.current_resource(conn).id
    audit_fields = %{last_change_at: DateTime.utc_now(), last_change_by: user_id}
    Loader.load(structure_records, field_records, relation_records, audit_fields)
  end
end
