defmodule TdDdWeb.MetadataController do
  use TdDdWeb, :controller

  require Logger

  alias Plug.Upload
  alias TdCache.DomainCache
  alias TdDd.DataStructures

  @worker Application.compile_env!(:td_dd, :loader_worker)

  action_fallback(TdDdWeb.FallbackController)

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
          type: :string required field type
          description: :string optional field description
          nullable: :boolean optional field nullability
          precision: :string optional field precision
          field_external_id: :string optional field external id
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
    claims = conn.assigns[:current_resource]

    with {:can, true} <- {:can, can_upload?(claims, params)},
         parent when not is_nil(parent) <-
           DataStructures.find_data_structure(%{external_id: parent_external_id}),
         {:ok, _} <-
           do_upload(conn, params),
         dsv <- DataStructures.get_latest_version_by_external_id(external_id) do
      render(conn, "show.json", data_structure_version: dsv)
    else
      {:can, false} -> {:can, false}
      nil -> {:error, :not_found}
      {:error, :graph, message, _changes_so_far} -> {:error, :unprocessable_entity, message}
    end
  end

  def upload(conn, %{"external_id" => external_id} = params) do
    claims = conn.assigns[:current_resource]

    with {:can, true} <- {:can, can_upload?(claims, params)},
         {:ok, _} <- do_upload(conn, params),
         dsv <- DataStructures.get_latest_version_by_external_id(external_id) do
      render(conn, "show.json", data_structure_version: dsv)
    end
  end

  def upload(conn, params) do
    claims = conn.assigns[:current_resource]

    if can_upload?(claims, params) do
      do_upload(conn, params)
      send_resp(conn, :accepted, "")
    else
      render_error(conn, :forbidden)
    end
  rescue
    e in RuntimeError ->
      Logger.error("While uploading #{e.message}")
      send_resp(conn, :unprocessable_entity, Jason.encode!(%{error: e.message}))
  end

  def do_upload(conn, params, opts \\ []) do
    [fields, structures, relations] =
      ["data_fields", "data_structures", "data_structure_relations"]
      |> Enum.map(&Map.get(params, &1))
      |> Enum.map(&copy_file/1)

    opts =
      params
      |> loader_opts()
      |> Keyword.merge(opts)

    load(conn, structures, fields, relations, opts)
  end

  def audit_params(conn) do
    %{user_id: user_id} = conn.assigns[:current_resource]
    %{ts: DateTime.utc_now(), last_change_by: user_id}
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

  defp load(conn, structures_file, fields_file, relations_file, opts) do
    claims = conn.assigns[:current_resource]
    audit = audit_params(conn)
    worker = Keyword.get(opts, :worker, @worker)
    worker.load(structures_file, fields_file, relations_file, audit, opts ++ [claims: claims])
  end

  def can_upload?(claims, %{"domain" => external_id}) do
    case DomainCache.external_id_to_id(external_id) do
      {:ok, domain_id} -> Bodyguard.permit?(DataStructures, :upload, claims, domain_id)
      _ -> Bodyguard.permit?(DataStructures, :upload, claims, :no_domain)
    end
  end

  def can_upload?(claims, _params), do: Bodyguard.permit?(DataStructures, :upload, claims)

  @spec loader_opts(map) :: keyword()
  def loader_opts(%{} = params) do
    params
    |> Map.take([
      "domain",
      "inherit_domains",
      "source",
      "external_id",
      "parent_external_id",
      "op",
      "job_id"
    ])
    |> Keyword.new(fn
      {"inherit_domains" = k, "true"} -> {String.to_atom(k), true}
      {"inherit_domains" = k, _} -> {String.to_atom(k), false}
      {"op", v} -> {:operation, v}
      {k, v} -> {String.to_atom(k), v}
    end)
  end
end
