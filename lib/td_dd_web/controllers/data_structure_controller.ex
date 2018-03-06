defmodule TdDDWeb.DataStructureController do
  use TdDDWeb, :controller
  alias TdDD.Auth.Guardian.Plug, as: GuardianPlug
  alias TdDD.DataStructures
  alias TdDD.DataStructures.DataStructure
  alias TdDDWeb.ErrorView

  action_fallback TdDDWeb.FallbackController

  def index(conn, _params) do
    data_structures = DataStructures.list_data_structures()
    render(conn, "index.json", data_structures: data_structures)
  end

  def create(conn, %{"data_structure" => data_structure_params}) do
    creation_params = data_structure_params
    |> Map.put("last_change_by", get_current_user_id(conn))
    |> Map.put("last_change_at", DateTime.utc_now())

    with {:ok, %DataStructure{} = data_structure} <- DataStructures.create_data_structure(creation_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", data_structure_path(conn, :show, data_structure))
      |> render("show.json", data_structure: data_structure)
    else
      _error ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(ErrorView, :"422.json")
    end
  end

  def show(conn, %{"id" => id}) do
    data_structure = DataStructures.get_data_structure!(id)
    render(conn, "show.json", data_structure: data_structure)
  end

  def update(conn, %{"id" => id, "data_structure" => data_structure_params}) do
    data_structure = DataStructures.get_data_structure!(id)

    update_params = data_structure_params
    |> Map.put("last_change_by", get_current_user_id(conn))
    |> Map.put("last_change_at", DateTime.utc_now())

    with {:ok, %DataStructure{} = data_structure} <- DataStructures.update_data_structure(data_structure, update_params) do
      render(conn, "show.json", data_structure: data_structure)
    else
      _error ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(ErrorView, :"422.json")
    end
  end

  def delete(conn, %{"id" => id}) do
    data_structure = DataStructures.get_data_structure!(id)
    with {:ok, %DataStructure{}} <- DataStructures.delete_data_structure(data_structure) do
      send_resp(conn, :no_content, "")
    end
  end

  defp get_current_user_id(conn) do
    GuardianPlug.current_resource(conn).id
  end

end
