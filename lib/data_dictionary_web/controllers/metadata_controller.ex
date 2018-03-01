defmodule DataDictionaryWeb.MetadataController do
  use DataDictionaryWeb, :controller

  alias Ecto.Adapters.SQL
  alias DataDictionary.Repo

  # alias DataDictionary.Auth.Guardian.Plug, as: GuardianPlug
  # alias DataDictionary.DataStructures
  # alias DataDictionary.DataStructures.DataField
  # alias DataDictionaryWeb.ErrorView

  @doc """
    Upload metadata:
      curl -F "data_structures=@data_structures.csv" -F "data_fields=@data_fields.csv"  http://localhost:8005/api/metadata

      INSERT INTO data_structures ("system", "group", "name", description, last_change_at, last_change_by, inserted_at, updated_at)
      VALUES ($1, $2, $3, $4, $5, 0, $5, $5)
      ON CONFLICT ("system", "group", "name")
      DO UPDATE SET description = $4, last_change_at = $5, last_change_by = 0, inserted_at = $5, updated_at = $5;

      INSERT INTO data_fields (data_structure_id, name, type, description, nullable, precision, last_change_at, last_change_by, inserted_at, updated_at)
      VALUES ((select id from data_structures where "system" = $1 and "group" = $2 and "name" = $3),
      $4, $5, $6, $7, $8, $9, 0, $9, $9)
        ON CONFLICT (data_structure_id, name)  DO UPDATE SET name = $4, type = $5, description = $6, nullable = $7, precision = $8, last_change_at = $9, last_change_by = 0, inserted_at = $9, updated_at = $9

  """
  def upload(conn, params) do

    start_time = DateTime.utc_now()

    data_structures = Map.get(params, "data_structures")
    data_fields = Map.get(params, "data_fields")

    data_structure_query = """
      INSERT INTO data_structures ("system", "group", "name", description, last_change_at, last_change_by, inserted_at, updated_at)
      VALUES ($1, $2, $3, $4, $5, 0, $5, $5)
      ON CONFLICT ("system", "group", "name")
      DO UPDATE SET description = $4, last_change_at = $5, last_change_by = 0, inserted_at = $5, updated_at = $5;
    """

    # This reads line by line
    data_structures_file = File.stream!(data_structures.path)
    data_structures_file
    |> CSV.decode
    |> Enum.each(fn
      {:ok, data} ->
        SQL.query!(Repo, data_structure_query, data ++ [DateTime.utc_now()])
      error -> IO.puts(error)
    end)

    data_field_query = """
      INSERT INTO data_fields (data_structure_id, name, type, description, nullable, precision, last_change_at, last_change_by, inserted_at, updated_at)
      VALUES ((select id from data_structures where "system" = $1 and "group" = $2 and "name" = $3),
      $4, $5, $6, $7, $8, $9, 0, $9, $9)
        ON CONFLICT (data_structure_id, name)  DO UPDATE SET name = $4, type = $5, description = $6, nullable = $7, precision = $8, last_change_at = $9, last_change_by = 0, inserted_at = $9, updated_at = $9
    """

    # This reads line by line
    data_fields_file = File.stream!(data_fields.path)
    data_fields_file
    |> CSV.decode
    |> Enum.each(fn
      {:ok, data} ->
        data  = data
        |> List.replace_at(6, Enum.at(data, 6) == "1")
        |> List.replace_at(7, String.to_integer(Enum.at(data, 7)))
        SQL.query!(Repo, data_field_query, data ++ [DateTime.utc_now()])
      error -> IO.puts(error)
    end)

    end_time = DateTime.utc_now()
    IO.puts(DateTime.diff(end_time, start_time))

    conn
    |> send_resp(:created, "")
  end
end
