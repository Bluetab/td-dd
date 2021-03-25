defmodule TdDdWeb.SystemMetadataController do
  use TdDdWeb, :controller

  import TdDdWeb.MetadataController,
    only: [do_upload: 3, audit_params: 1, loader_opts: 1, can_upload?: 2]

  require Logger

  alias TdDd.Systems
  alias TdDd.Systems.System

  action_fallback(TdDdWeb.FallbackController)

  def create(conn, %{"system_id" => external_id, "data_structures" => %Plug.Upload{}} = params) do
    claims = conn.assigns[:current_resource]

    with {:can, true} <- {:can, can_upload?(claims, params)} do
      %System{id: system_id} = Systems.get_by!(external_id: external_id)
      do_upload(conn, params, system_id: system_id, worker: worker())
      send_resp(conn, :accepted, "")
    end
  end

  def create(conn, %{"system_id" => external_id} = params) do
    claims = conn.assigns[:current_resource]

    with {:can, true} <- {:can, can_upload?(claims, params)} do
      system = Systems.get_by!(external_id: external_id)
      audit = audit_params(conn)
      opts = loader_opts(params)
      worker().load(system, params, audit, opts)
      send_resp(conn, :accepted, "")
    end
  end

  defp worker, do: Application.get_env(:td_dd, :loader_worker)
end
