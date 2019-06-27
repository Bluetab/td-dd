defmodule TdDdWeb.MetadataController do
  require Logger
  use TdDdWeb, :controller

  alias Plug.Upload
  alias TdCache.TaxonomyCache
  alias TdDd.Auth.Guardian.Plug, as: GuardianPlug
  alias TdDd.CSV.Reader
  alias TdDd.Loader.LoaderWorker
  alias TdDd.Systems
  alias TdDd.Systems.System

  @structure_import_schema Application.get_env(:td_dd, :metadata)[:structure_import_schema]
  @structure_import_required Application.get_env(:td_dd, :metadata)[:structure_import_required]
  @field_import_schema Application.get_env(:td_dd, :metadata)[:field_import_schema]
  @field_import_required Application.get_env(:td_dd, :metadata)[:field_import_required]
  @relation_import_schema Application.get_env(:td_dd, :metadata)[:relation_import_schema]
  @relation_import_required Application.get_env(:td_dd, :metadata)[:relation_import_required]

  def upload_by_system(conn, %{"system_id" => external_id} = params) do
    # TODO: Complete implementation once the metada is loaded by System
    with %System{id: system_id} <- Systems.get_system_by_external_id(external_id) do
      do_upload(conn, params, system_id)
      send_resp(conn, :accepted, "")
    else
      _ -> send_resp(conn, :not_found, Poison.encode!(%{error: "system.not_found"}))
    end
  rescue
    e in RuntimeError ->
      Logger.error("While uploading #{e.message}")
      send_resp(conn, :unprocessable_entity, Poison.encode!(%{error: e.message}))
  end

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
    send_resp(conn, :accepted, "")
  rescue
    e in RuntimeError ->
      Logger.error("While uploading #{e.message}")
      send_resp(conn, :unprocessable_entity, Poison.encode!(%{error: e.message}))
  end

  defp do_upload(conn, params, system_id \\ nil) do
    {:ok, field_recs} = params |> Map.get("data_fields") |> parse_data_fields(system_id)

    {:ok, structure_recs} =
      params |> Map.get("data_structures") |> parse_data_structures(system_id)

    {:ok, relation_recs} =
      params |> Map.get("data_structure_relations") |> parse_data_structure_relations(system_id)

    load(conn, structure_recs, field_recs, relation_recs)
  end

  defp parse_data_structures(nil, _), do: {:ok, []}

  defp parse_data_structures(%Upload{path: path}, system_id) do
    domain_map = TaxonomyCache.get_domain_name_to_id_map()
    system_map = get_system_map(system_id)

    defaults =
      case system_id do
        nil -> %{version: 0}
        _ -> %{system_id: system_id, version: 0}
      end

    path
    |> File.stream!()
    |> Reader.read_csv(
      domain_map: domain_map,
      system_map: system_map,
      defaults: defaults,
      schema: @structure_import_schema,
      required: @structure_import_required
    )
  end

  defp parse_data_fields(nil, _), do: {:ok, []}

  defp parse_data_fields(%Upload{path: path}, system_id) do
    defaults =
      case system_id do
        nil -> %{version: 0, external_id: nil}
        _ -> %{version: 0, external_id: nil, system_id: system_id}
      end

    system_map = get_system_map(system_id)

    path
    |> File.stream!()
    |> Reader.read_csv(
      defaults: defaults,
      system_map: system_map,
      schema: @field_import_schema,
      required: @field_import_required,
      booleans: ["nullable"]
    )
  end

  defp parse_data_structure_relations(nil, _), do: {:ok, []}

  defp parse_data_structure_relations(%Upload{path: path}, system_id) do
    system_map = get_system_map(system_id)

    defaults =
      case system_id do
        nil -> %{}
        _ -> %{system_id: system_id}
      end

    path
    |> File.stream!()
    |> Reader.read_csv(
      defaults: defaults,
      system_map: system_map,
      schema: @relation_import_schema,
      required: @relation_import_required
    )
  end

  defp get_system_map(nil), do: Systems.get_system_name_to_id_map()
  defp get_system_map(_system_id), do: nil

  defp load(conn, structure_records, field_records, relation_records) do
    user_id = GuardianPlug.current_resource(conn).id

    audit_fields = %{
      last_change_at: DateTime.truncate(DateTime.utc_now(), :second),
      last_change_by: user_id
    }

    LoaderWorker.load(structure_records, field_records, relation_records, audit_fields)
  end
end
