defmodule TdDdWeb.DataFieldController do
  use TdDdWeb, :controller
  use PhoenixSwagger
  import Canada, only: [can?: 2]
  alias TdDd.Audit
  alias TdDd.Auth.Guardian.Plug, as: GuardianPlug
  alias TdDd.DataStructures
  alias TdDd.DataStructures.DataField
  alias TdDdWeb.ErrorView
  alias TdDdWeb.SwaggerDefinitions

  action_fallback(TdDdWeb.FallbackController)

  @events %{
    update_data_field: "update_data_field",
    create_data_field: "create_data_field",
    delete_data_field: "delete_data_field"
  }

  def swagger_definitions do
    SwaggerDefinitions.data_field_swagger_definitions()
  end

  swagger_path :index do
    description("List Data Fields")
    response(200, "OK", Schema.ref(:DataFieldsResponse))
  end

  def index(conn, _params) do
    data_fields = DataStructures.list_data_fields()
    render(conn, "index.json", data_fields: data_fields)
  end

  swagger_path :data_structure_fields do
    description("List data structure data fields")

    parameters do
      data_structure_id(:path, :integer, "Data Structure ID", required: true)
    end

    response(200, "OK", Schema.ref(:DataFieldsResponse))
    response(403, "Unauthorized")
  end

  def data_structure_fields(conn, %{"data_structure_id" => data_structure_id}) do
    user = conn.assigns[:current_user]
    data_structure = DataStructures.get_data_structure!(data_structure_id)

    with true <- can?(user, view_data_structure(data_structure)) do
      data_fields = DataStructures.get_latest_fields(data_structure_id)
      render(conn, "index.json", data_fields: data_fields)
    else
      false ->
        conn
        |> put_status(:forbidden)
        |> put_view(ErrorView)
        |> render("403.json")
    end
  end

  swagger_path :create do
    description("Creates Data Fields")
    produces("application/json")

    parameters do
      data_field(:body, Schema.ref(:DataFieldCreate), "Data Field create attrs")
    end

    response(201, "OK", Schema.ref(:DataFieldResponse))
    response(400, "Client Error")
  end

  def create(conn, %{"data_field" => data_field_params}) do
    creation_params =
      data_field_params
      |> Map.put("last_change_by", get_current_user_id(conn))
      |> Map.put("last_change_at", DateTime.truncate(DateTime.utc_now(), :second))
      |> Map.put("metadata", %{})

    with {:ok, %DataField{} = data_field} <- DataStructures.create_data_field(creation_params) do
      audit = %{
        "audit" => %{
          "resource_id" => data_field.id,
          "resource_type" => "data_field",
          "payload" => data_field_params
        }
      }

      Audit.create_event(conn, audit, @events.create_data_field)

      conn
      |> put_status(:created)
      |> put_resp_header("location", Routes.data_field_path(conn, :show, data_field))
      |> render("show.json", data_field: data_field)
    else
      _error ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(ErrorView)
        |> render("422.json")
    end
  end

  swagger_path :show do
    description("Show Data Field")
    produces("application/json")

    parameters do
      id(:path, :integer, "Data Field ID", required: true)
    end

    response(200, "OK", Schema.ref(:DataFieldResponse))
    response(400, "Client Error")
  end

  def show(conn, %{"id" => id}) do
    data_field = DataStructures.get_data_field!(id)
    render(conn, "show.json", data_field: data_field)
  end

  swagger_path :update do
    description("Update Data Fields")
    produces("application/json")

    parameters do
      id(:path, :integer, "Data Field ID", required: true)
      data_field(:body, Schema.ref(:DataFieldUpdate), "Data Field update attrs")
    end

    response(201, "OK", Schema.ref(:DataFieldResponse))
    response(400, "Client Error")
  end

  def update(conn, %{"id" => id, "data_field" => data_field_params}) do
    data_field = DataStructures.get_data_field!(id)

    update_params =
      data_field_params
      |> Map.put("last_change_by", get_current_user_id(conn))
      |> Map.put("last_change_at", DateTime.truncate(DateTime.utc_now(), :second))

    with {:ok, %DataField{} = data_field} <-
           DataStructures.update_data_field(data_field, update_params) do
      audit = %{
        "audit" => %{
          "resource_id" => id,
          "resource_type" => "data_field",
          "payload" => update_params |> Map.drop(["last_change_at", "last_change_by"])
        }
      }

      Audit.create_event(conn, audit, @events.update_data_field)
      render(conn, "show.json", data_field: data_field)
    else
      _error ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(ErrorView)
        |> render("422.json")
    end
  end

  swagger_path :delete do
    description("Delete Data Field")
    produces("application/json")

    parameters do
      id(:path, :integer, "Data Field ID", required: true)
    end

    response(204, "No Content")
    response(400, "Client Error")
  end

  def delete(conn, %{"id" => id}) do
    data_field = DataStructures.get_data_field!(id)

    with {:ok, %DataField{}} <- DataStructures.delete_data_field(data_field) do
      audit = %{
        "audit" => %{"resource_id" => id, "resource_type" => "data_field", "payload" => %{}}
      }

      Audit.create_event(conn, audit, @events.delete_data_field)
      send_resp(conn, :no_content, "")
    end
  end

  defp get_current_user_id(conn) do
    GuardianPlug.current_resource(conn).id
  end
end
