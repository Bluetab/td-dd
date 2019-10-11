defmodule TdDdWeb.MetadataController do
  use TdDdWeb, :controller

  import Canada, only: [can?: 2]

  alias Jason, as: JSON
  alias Plug.Upload
  alias TdCache.TaxonomyCache
  alias TdDd.Auth.Guardian.Plug, as: GuardianPlug
  alias TdDd.CSV.Reader
  alias TdDd.DataStructures
  alias TdDd.Loader.LoaderWorker
  alias TdDd.Systems
  alias TdDd.Systems.System

  require Logger

  @structure_import_schema Application.get_env(:td_dd, :metadata)[:structure_import_schema]
  @structure_import_required Application.get_env(:td_dd, :metadata)[:structure_import_required]
  @structure_import_boolean Application.get_env(:td_dd, :metadata)[:structure_import_boolean]
  @field_import_schema Application.get_env(:td_dd, :metadata)[:field_import_schema]
  @field_import_required Application.get_env(:td_dd, :metadata)[:field_import_required]
  @relation_import_schema Application.get_env(:td_dd, :metadata)[:relation_import_schema]
  @relation_import_required Application.get_env(:td_dd, :metadata)[:relation_import_required]

  def upload_by_system(conn, %{"system_id" => external_id} = params) do
    # TODO: Complete implementation once the metada is loaded by System
    with %System{id: system_id} <- Systems.get_system_by_external_id(external_id) do
      do_upload(conn, params, system_id: system_id)
      send_resp(conn, :accepted, "")
    else
      _ -> send_resp(conn, :not_found, JSON.encode!(%{error: "system.not_found"}))
    end
  rescue
    e in RuntimeError ->
      Logger.error("While uploading #{e.message}")
      send_resp(conn, :unprocessable_entity, JSON.encode!(%{error: e.message}))
  end

  @doc """
    Upload metadata:

      data_structures.csv: 
          external_id: :string required structure external id (unique within system)
          name: :string required structure name
          system: :string required system name
          group: :string required group name
          type: :string required structure type
          class: :string optional structure class (e.g. "field")
          description: :string optional structure description
          ou: :string optional domain name
          metadata: :map (headers prefixed with "m:", e.g. "m:data_type" will be loaded into this map)
      data_fields.csv:
          external_id: :string required external id of parent structure
          field_name: :string required field name
          description: :string optional field description
          nullable: :boolean optional field nullability
          precision: :string optional field precision
          type: :string optional field data type
          metadata: :map (headers prefixed with "m:", e.g. "m:data_type" will be loaded into this map)
      data_structure_relations.csv:
          parent_external_id: :string required external id of parent
          child_external_id: :string required external id of child

      curl -H "Content-Type: application/json" -X POST -d '{"user":{"user_name":"xxx","password":"xxx"}}' http://localhost:4001/api/sessions
      curl -H "Authorization: Bearer xxx" -F "data_structures=@data_structures.csv" -F "data_fields=@data_fields.csv"  http://localhost:4005/api/data_structures/metadata

      To synchronously upload metadata for a specific structure and it's children, the external_id of
      the parent structure can be specified using the "external_id" form field. An optional "parent_external_id"
      can also be specified, in which case the parent must aleady exist:

      curl -H "Authorization: Bearer xxx" -F "data_structures=@data_structures.csv" -F "external_id=SOME_EXTERNAL_ID"  http://localhost:4005/api/data_structures/metadata
  """
  def upload(
        conn,
        %{"external_id" => external_id, "parent_external_id" => parent_external_id} = params
      ) do
    user = conn.assigns[:current_user]

    with true <- can?(user, upload(DataStructure)),
         parent when not is_nil(parent) <-
           DataStructures.find_data_structure(%{external_id: parent_external_id}),
         :ok, _ <-
           do_upload(conn, params,
             external_id: external_id,
             parent_external_id: parent_external_id
           ),
         dsv <- DataStructures.get_latest_version_by_external_id(external_id, enrich: [:ancestry]) do
      render(conn, "show.json", data_structure_version: dsv)
    else
      false ->
        render_error(conn, :forbidden)

      nil ->
        render_error(conn, :not_found)

      _error ->
        render_error(conn, :unprocessable_entity)
    end
  end

  def upload(conn, %{"external_id" => external_id} = params) do
    user = conn.assigns[:current_user]

    with true <- can?(user, upload(DataStructure)),
         :ok, _ <- do_upload(conn, params, external_id: external_id),
         dsv <- DataStructures.get_latest_version_by_external_id(external_id, enrich: [:ancestry]) do
      render(conn, "show.json", data_structure_version: dsv)
    else
      false ->
        render_error(conn, :forbidden)

      _error ->
        render_error(conn, :unprocessable_entity)
    end
  end

  def upload(conn, params) do
    do_upload(conn, params)
    send_resp(conn, :accepted, "")
  rescue
    e in RuntimeError ->
      Logger.error("While uploading #{e.message}")
      send_resp(conn, :unprocessable_entity, JSON.encode!(%{error: e.message}))
  end

  defp do_upload(conn, params, opts \\ []) do
    system_id = opts[:system_id]

    {:ok, field_recs} = params |> Map.get("data_fields") |> parse_data_fields(system_id)

    {:ok, structure_recs} =
      params |> Map.get("data_structures") |> parse_data_structures(system_id)

    {:ok, relation_recs} =
      params |> Map.get("data_structure_relations") |> parse_data_structure_relations(system_id)

    load(conn, structure_recs, field_recs, relation_recs, opts)
  end

  defp parse_data_structures(nil, _), do: {:ok, []}

  defp parse_data_structures(%Upload{path: path}, system_id) do
    domain_map = TaxonomyCache.get_domain_name_to_id_map()
    system_map = get_system_map(system_id)

    defaults =
      case system_id do
        nil -> %{}
        _ -> %{system_id: system_id}
      end

    path
    |> File.stream!()
    |> Reader.read_csv(
      domain_map: domain_map,
      system_map: system_map,
      defaults: defaults,
      schema: @structure_import_schema,
      required: @structure_import_required,
      booleans: @structure_import_boolean
    )
  end

  defp parse_data_fields(nil, _), do: {:ok, []}

  defp parse_data_fields(%Upload{path: path}, system_id) do
    defaults =
      case system_id do
        nil -> %{external_id: nil}
        _ -> %{external_id: nil, system_id: system_id}
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

  defp load(conn, structure_records, field_records, relation_records, opts) do
    user_id = GuardianPlug.current_resource(conn).id
    ts = DateTime.truncate(DateTime.utc_now(), :second)
    audit_fields = %{ts: ts, last_change_by: user_id}
    LoaderWorker.load(structure_records, field_records, relation_records, audit_fields, opts)
  end
end
