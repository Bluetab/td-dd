defmodule TdDdWeb.MetadataController do
  require Logger
  use TdDdWeb, :controller

  alias Ecto.Adapters.SQL
  alias TdDd.Repo
  alias TdDd.Auth.Guardian.Plug, as: GuardianPlug

  @data_structure_query  """
    INSERT INTO data_structures ("system", "group", "name", description, last_change_at, last_change_by, inserted_at, updated_at)
    VALUES ($1, $2, $3, $4, $6, $5, $6, $6)
    ON CONFLICT ("system", "group", "name")
    DO UPDATE SET description = $4, last_change_at = $6, last_change_by = $5, updated_at = $6;
  """

  @data_field_query  """
    INSERT INTO data_fields (data_structure_id, name, type, description, nullable, precision, business_concept_id, last_change_at, last_change_by, inserted_at, updated_at)
    VALUES ((select id from data_structures where "system" = $1 and "group" = $2 and "name" = $3),
    $4, $5, $6, $7, $8, $9, $11, $10, $11, $11)
    ON CONFLICT (data_structure_id, name)
    DO UPDATE SET name = $4, type = $5, description = $6, nullable = $7, precision = $8, business_concept_id = $9, last_change_at = $11, last_change_by = $10, updated_at = $11
  """

  @data_structures_param "data_structures"

  @data_fields_param "data_fields"

  @doc """
    Upload metadata:

      data_structures.csv: system, group, name, description
      data_fields.csv: system, group, name, field name, type, descripiton, nullable, precision, business_concept_id

      curl -H "Content-Type: application/json" -X POST -d '{"user":{"user_name":"xxx","password":"xxx"}}' http://localhost:4001/api/sessions
      curl -H "authorization: Bearer xxx" -F "data_structures=@data_structures.csv" -F "data_fields=@data_fields.csv"  http://localhost:8005/api/metadata

      INSERT INTO data_structures ("system", "group", "name", description, last_change_at, last_change_by, inserted_at, updated_at)
      VALUES ($1, $2, $3, $4, $6, $5, $6, $6)
      ON CONFLICT ("system", "group", "name")
      DO UPDATE SET description = $4, last_change_at = $6, last_change_by = $5, inserted_at = $6, updated_at = $6;

      INSERT INTO data_fields (data_structure_id, name, type, description, nullable, precision, last_change_at, last_change_by, inserted_at, updated_at)
      VALUES ((select id from data_structures where "system" = $1 and "group" = $2 and "name" = $3),
      $4, $5, $6, $7, $8, $10, $9, $10, $10)
      ON CONFLICT (data_structure_id, name)
      DO UPDATE SET name = $4, type = $5, description = $6, nullable = $7, precision = $8, last_change_at = $10, last_change_by = $9, inserted_at = $10, updated_at = $10

  """
  def upload(conn, params) do
    do_upload(conn, params)
    send_resp(conn, :ok, "")
  rescue e in RuntimeError ->
    Logger.error "While uploading #{e.message}"
    send_resp(conn, :unprocessable_entity, Poison.encode!(%{error: e.message}))
  end

  defp do_upload(conn, params) do

    Logger.info "Uploading metadata..."

    start_time = DateTime.utc_now()

    data_structures_upload = Map.get(params, @data_structures_param)
    data_fields_upload = Map.get(params, @data_fields_param)

    Repo.transaction(fn ->
      upload_in_transaction(conn, data_structures_upload.path, data_fields_upload.path)
    end)

    end_time = DateTime.utc_now()

    Logger.info "Metadata uploaded. Elapsed seconds: #{DateTime.diff(end_time, start_time)}"

  end

  defp upload_in_transaction(conn, data_structures_path, data_fields_path) do

    Logger.info "Uploading data structures..."

    data_structures_path
    |> File.stream!
    |> CSV.decode!
    |> Enum.each(fn(data) ->
      data = add_user_and_date_time(conn, data)
      SQL.query!(Repo, @data_structure_query, data)
    end)

    Logger.info "Uploading data fields..."

    data_fields_path
    |> File.stream!
    |> CSV.decode!
    |> Enum.each(fn(data) ->
      data = data
      |> List.update_at(6, &(&1 == "1")) # nullable

      data = add_user_and_date_time(conn, data)
      SQL.query!(Repo, @data_field_query, data)
    end)

  end

  defp add_user_and_date_time(conn, data) do
    data ++ [GuardianPlug.current_resource(conn).id, DateTime.utc_now()]
  end

end
