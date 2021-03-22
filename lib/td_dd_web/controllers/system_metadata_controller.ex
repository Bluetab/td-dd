defmodule TdDdWeb.SystemMetadataController do
  use TdDdWeb, :controller

  import TdDdWeb.MetadataController, only: [do_upload: 3, can_upload?: 2]

  require Logger

  alias TdDd.Systems
  alias TdDd.Systems.System

  action_fallback(TdDdWeb.FallbackController)

  plug :set_content_type when action in [:create]

  def set_content_type(conn, _opts) do
    case get_req_header(conn, "content-type") do
      [content_type] -> assign(conn, :content_type, content_type)
      _ -> conn
    end
  end

  def create(
        %{assigns: %{content_type: "multipart/form-data" <> _}} = conn,
        %{"system_id" => external_id} = params
      ) do
    claims = conn.assigns[:current_resource]

    with {:can, true} <- {:can, can_upload?(claims, params)} do
      %System{id: system_id} = Systems.get_by!(external_id: external_id)
      do_upload(conn, params, system_id: system_id, worker: worker())
      send_resp(conn, :accepted, "")
    end
  end

  defp worker, do: Application.get_env(:td_dd, :loader_worker)
end
