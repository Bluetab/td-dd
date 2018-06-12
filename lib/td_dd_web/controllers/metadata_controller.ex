defmodule TdDdWeb.MetadataController do
  require Logger
  use TdDdWeb, :controller

  alias Ecto.Adapters.SQL
  alias TdDd.Repo
  alias TdDd.Auth.Guardian.Plug, as: GuardianPlug

  @data_structure_keys Application.get_env(:td_dd, :metadata)[:data_structure_keys]
  @data_field_keys Application.get_env(:td_dd, :metadata)[:data_field_keys]
  @data_structure_query Application.get_env(:td_dd, :metadata)[:data_structure_query]
  @data_field_query Application.get_env(:td_dd, :metadata)[:data_field_query]
  @data_structure_modifiable_fields Application.get_env(:td_dd, :metadata)[:data_structure_modifiable_fields]
  @data_field_modifiable_fields Application.get_env(:td_dd, :metadata)[:data_field_modifiable_fields]

  @data_structures_param "data_structures"

  @data_fields_param "data_fields"

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

    data_structure_keys = Enum.reverse(@data_structure_keys)

    data_structures_path
    |> File.stream!
    |> CSV.decode!(separator: ?;, headers: true)
    |> Enum.each(fn(data) ->
      last_change_at = DateTime.utc_now()
      input = data
      |> add_metadata(@data_structure_modifiable_fields, last_change_at)
      |> to_array(data_structure_keys)
      |> add_user_and_date_time(conn, last_change_at)
      SQL.query!(Repo, @data_structure_query, input)
    end)

    Logger.info "Uploading data fields..."

    data_field_keys = Enum.reverse(@data_field_keys)

    data_fields_path
    |> File.stream!
    |> CSV.decode!(separator: ?;, headers: true)
    |> Enum.each(fn(data) ->
      last_change_at = DateTime.utc_now()
      input = data
      |> add_metadata(@data_field_modifiable_fields, last_change_at)
      |> to_array(data_field_keys)
      |> add_user_and_date_time(conn, last_change_at)
      SQL.query!(Repo, @data_field_query, input)
    end)

  end

  defp to_array(data, data_keys) do
    data_keys
    |> Enum.reduce([], &([get_value(data, &1)| &2]))
  end

  defp get_value(data, "nullable" = name) do
    case String.downcase(Map.get(data, name))  do
      "" -> nil
      value -> Enum.member?(["t", "true", "y", "yes", "on", "1"], value)
    end
  end
  defp get_value(data, name), do: Map.get(data, name)

  defp add_user_and_date_time(data, conn, last_change_at) do
    data ++ [GuardianPlug.current_resource(conn).id, last_change_at]
  end

 defp add_metadata(data, fields, last_change_at) do
   metadata = fields
   |> Enum.reduce(%{}, &Map.put(&2, &1, Map.get(data, &1)))
   |> Map.put("last_change_at", last_change_at)
   Map.put(data, "metadata", metadata)
 end

end
