defmodule TdDd.Audit do
  @moduledoc """
    Manage TdAudit api service
  """

  alias TdDd.Auth.Guardian.Plug, as: GuardianPlug

  @td_audit_api Application.get_env(:td_dd, :audit_service)[:api_service]
  @service "td_dd"

  def create_event(conn, %{"audit" => event_params}, event) do
    event_params =
      event_params
      |> Map.put("event", event)
      |> Map.put("ts", DateTime.to_string(DateTime.utc_now()))
      |> Map.put("service", @service)
    create_event(conn, %{"audit" => event_params})
  end
  def create_event(conn, event_params) do
    event_params = add_user_info(conn, event_params)
    @td_audit_api.post_audits(event_params)
  end

  def add_user_info(conn, %{"audit" => event_params}) do
    current_user = GuardianPlug.current_resource(conn)
    event_params =
      event_params
      |> Map.put("user_id", current_user.id)
      |> Map.put("user_name", current_user.user_name)
    %{"audit" => event_params}
  end
end
