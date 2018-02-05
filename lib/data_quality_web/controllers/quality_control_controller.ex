defmodule DataQualityWeb.QualityControlController do
  use DataQualityWeb, :controller

  alias DataQuality.QualityControls
  alias DataQuality.QualityControls.QualityControl

  action_fallback DataQualityWeb.FallbackController

  def index(conn, _params) do
    quality_controls = QualityControls.list_quality_controls()
    render(conn, "index.json", quality_controls: quality_controls)
  end

  def create(conn, %{"quality_control" => quality_control_params}) do
    with {:ok, %QualityControl{} = quality_control} <- QualityControls.create_quality_control(quality_control_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", quality_control_path(conn, :show, quality_control))
      |> render("show.json", quality_control: quality_control)
    end
  end

  def show(conn, %{"id" => id}) do
    quality_control = QualityControls.get_quality_control!(id)
    render(conn, "show.json", quality_control: quality_control)
  end

  def update(conn, %{"id" => id, "quality_control" => quality_control_params}) do
    quality_control = QualityControls.get_quality_control!(id)

    with {:ok, %QualityControl{} = quality_control} <- QualityControls.update_quality_control(quality_control, quality_control_params) do
      render(conn, "show.json", quality_control: quality_control)
    end
  end

  def delete(conn, %{"id" => id}) do
    quality_control = QualityControls.get_quality_control!(id)
    with {:ok, %QualityControl{}} <- QualityControls.delete_quality_control(quality_control) do
      send_resp(conn, :no_content, "")
    end
  end
end
