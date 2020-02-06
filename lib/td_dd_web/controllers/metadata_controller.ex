defmodule TdDdWeb.MetadataController do
  use TdDdWeb, :controller

  import Canada, only: [can?: 2]

  alias Jason, as: JSON
  alias Plug.Upload
  alias TdCache.TaxonomyCache
  alias TdDd.Auth.Guardian.Plug, as: GuardianPlug
  alias TdDd.DataStructures
  alias TdDd.Loader.LoaderWorker
  alias TdDd.Systems

  require Logger

  def upload_by_system(conn, %{"system_id" => external_id} = params) do
    alias TdDd.Systems.System

    # TODO: Complete implementation once the metada is loaded by System
    user = conn.assigns[:current_user]

    with true <- can_upload?(user, params),
         %System{id: system_id} <- Systems.get_system_by_external_id(external_id) do
      do_upload(conn, params, system_id: system_id)
      send_resp(conn, :accepted, "")
    else
      false -> render_error(conn, :forbidden)
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

    with true <- can_upload?(user, params),
         parent when not is_nil(parent) <-
           DataStructures.find_data_structure(%{external_id: parent_external_id}),
         :ok,
         _ <-
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

    with true <- can_upload?(user, params),
         :ok,
         _ <- do_upload(conn, params, external_id: external_id),
         dsv <- DataStructures.get_latest_version_by_external_id(external_id, enrich: [:ancestry]) do
      render(conn, "show.json", data_structure_version: dsv)
    else
      false ->
        render_error(conn, :forbidden)

      _error ->
        render_error(conn, :unprocessable_entity)
    end
  end

  def upload(conn, %{"nodes" => _} = params), do: upload_lineage(conn, params)
  def upload(conn, %{"rels" => _} = params), do: upload_lineage(conn, params)

  def upload(conn, params) do
    user = conn.assigns[:current_user]

    with true <- can_upload?(user, params) do
      do_upload(conn, params)
      send_resp(conn, :accepted, "")
    else
      false -> render_error(conn, :forbidden)
    end
  rescue
    e in RuntimeError ->
      Logger.error("While uploading #{e.message}")
      send_resp(conn, :unprocessable_entity, JSON.encode!(%{error: e.message}))
  end

  defp do_upload(conn, params, opts \\ []) do
    [fields, structures, relations] =
      ["data_fields", "data_structures", "data_structure_relations"]
      |> Enum.map(&Map.get(params, &1))
      |> Enum.map(&copy_file/1)

    load(conn, structures, fields, relations, with_domain(opts, params))
  end

  defp upload_lineage(conn, %{} = params) do
    user = conn.assigns[:current_user]

    with true <- can_upload?(user, params) do
      case do_upload_lineage(params) do
        :ok -> send_resp(conn, :accepted, "")
        :error -> render_error(conn, :insufficient_storage)
      end
    else
      false -> render_error(conn, :forbidden)
    end
  end

  defp copy_file(nil), do: nil

  defp copy_file(%Upload{path: path, filename: filename}) do
    destination_file =
      System.tmp_dir()
      |> Path.join("#{:os.system_time(:milli_seconds)}-#{filename}")

    case File.cp(path, "#{destination_file}") do
      :ok -> destination_file
    end
  end

  defp do_upload_lineage(%{} = params) do
    import_dir = Application.get_env(:td_dd, :import_dir)
    params
    |> Map.take(["nodes", "rels"])
    |> Map.values()
    |> Enum.map(fn %Upload{path: path, filename: filename} ->
      {path, Path.join([import_dir, filename])}
    end)
    |> Enum.map(fn {source_file, dest_file} -> copy(source_file, dest_file) end)
    |> check_status()
  end

  defp copy(source, dest) do
    source
    |> File.cp(dest)
    |> log_error(source, dest)
  end

  defp log_error(:ok, _, _), do: :ok
  defp log_error(error, source, dest) do
    Logger.warn("Error copying #{source} to #{dest}: #{inspect(error)}")
    error
  end

  defp check_status([:ok]), do: :ok
  defp check_status([:ok | tail]), do: check_status(tail)
  defp check_status([{:error, reason} | _]) do
    Logger.warn("Error copying file: #{inspect(reason)}")
    :error
  end
  defp check_status(_), do: :error

  defp load(conn, structure_records, field_records, relation_records, opts) do
    user_id = GuardianPlug.current_resource(conn).id
    ts = DateTime.truncate(DateTime.utc_now(), :second)
    audit_fields = %{ts: ts, last_change_by: user_id}
    LoaderWorker.load(structure_records, field_records, relation_records, audit_fields, opts)
  end

  defp can_upload?(user, %{"domain" => domain_name}) do
    domain_id =
      TaxonomyCache.get_domain_name_to_id_map()
      |> Map.get(domain_name)

    can?(user, upload(domain_id))
  end

  defp can_upload?(user, _params), do: can?(user, upload(DataStructure))

  defp with_domain(opts, params) do
    domain = Map.get(params, "domain")
    Keyword.put(opts, :domain, domain)
  end
end
