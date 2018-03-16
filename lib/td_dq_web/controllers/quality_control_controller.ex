defmodule TdDqWeb.QualityControlController do
  use TdDqWeb, :controller
  use PhoenixSwagger

  alias TdDq.QualityControls
  alias TdDq.QualityControls.QualityControl
  alias TdDqWeb.SwaggerDefinitions
  alias TdDqWeb.ErrorView
  alias Poison, as: JSON

  action_fallback TdDqWeb.FallbackController

  def swagger_definitions do
    SwaggerDefinitions.quality_control_definitions()
  end

  swagger_path :index do
    get "/quality_controls"
    description "List Quality Controls"
    response 200, "OK", Schema.ref(:QualityControlsResponse)
  end

  def index(conn, _params) do
    quality_controls = QualityControls.list_quality_controls()
    render(conn, "index.json", quality_controls: quality_controls)
  end

  swagger_path :create do
    post "/quality_controls"
    description "Creates a Quality Control"
    produces "application/json"
    parameters do
      quality_control :body, Schema.ref(:QualityControlCreate), "Quality Control create attrs"
    end
    response 201, "Created", Schema.ref(:QualityControlResponse)
    response 400, "Client Error"
  end

  def create(conn, %{"quality_control" => quality_control_params}) do

    quality_control_params =
      if conn.assigns.current_user do
        Map.put_new(quality_control_params, "updated_by", conn.assigns.current_user.id)
      else
        quality_control_params
      end

    with {:ok, %QualityControl{} = quality_control} <- QualityControls.create_quality_control(quality_control_params),
         true <- validate_type_parameters(quality_control_params)
    do
      conn
      |> put_status(:created)
      |> put_resp_header("location", quality_control_path(conn, :show, quality_control))
      |> render("show.json", quality_control: quality_control)
    else
      {:error, _changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(ErrorView, :"422.json")
    end
  end

  swagger_path :show do
    get "/quality_controls/{id}"
    description "Show Quality Control"
    produces "application/json"
    parameters do
      id :path, :integer, "Quality Control ID", required: true
    end
    response 200, "OK", Schema.ref(:QualityControlResponse)
    response 400, "Client Error"
  end

  def show(conn, %{"id" => id}) do
    quality_control = QualityControls.get_quality_control!(id)
    render(conn, "show.json", quality_control: quality_control)
  end

  swagger_path :update do
    put "/quality_controls/{id}"
    description "Updates Quality Control"
    produces "application/json"
    parameters do
      quality_control :body, Schema.ref(:QualityControlUpdate), "Quality Control update attrs"
      id :path, :integer, "Quality Control ID", required: true
    end
    response 200, "OK", Schema.ref(:QualityControlResponse)
    response 400, "Client Error"
  end

  def update(conn, %{"id" => id, "quality_control" => quality_control_params}) do
    quality_control = QualityControls.get_quality_control!(id)
    quality_control_params =
      if conn.assigns.current_user do
        Map.put_new(quality_control_params, "updated_by", conn.assigns.current_user.id)
      else
        quality_control_params
      end

    with {:ok, %QualityControl{} = quality_control} <- QualityControls.update_quality_control(quality_control, quality_control_params) do
      render(conn, "show.json", quality_control: quality_control)
    end
  end

  swagger_path :delete do
    delete "/quality_controls/{id}"
    description "Delete Quality Control"
    produces "application/json"
    parameters do
      id :path, :integer, "Quality Control ID", required: true
    end
    response 200, "OK"
    response 400, "Client Error"
  end

  def delete(conn, %{"id" => id}) do
    quality_control = QualityControls.get_quality_control!(id)
    with {:ok, %QualityControl{}} <- QualityControls.delete_quality_control(quality_control) do
      send_resp(conn, :no_content, "")
    end
  end

  defp get_type_parameters(type_name) do
    file_name = Application.get_env(:td_dq, :qc_types_file)
    file_path = Path.join(:code.priv_dir(:td_dq), file_name)

    json = file_path
    |> File.read!
    |> JSON.decode!

    Enum.find(json, &(&1["type_name"] == type_name))["type_parameters"]
  end

  defp validate_type_parameters(quality_control_params) do
    type_parameters = get_type_parameters(quality_control_params["type"])
    if type_parameters != nil do
      length(type_parameters) == length(Map.keys(quality_control_params["type_params"]))
    else
      true
    end
  end

  def type_parameters_file(conn, _params) do
    json conn, get_type_parameters("Integer Values Range")
  end
end
