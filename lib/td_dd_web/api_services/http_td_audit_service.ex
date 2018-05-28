defmodule TdDdWeb.ApiServices.HttpTdAuditService do
  @moduledoc false

  alias Poison, as: JSON

  def post_audits(%{"audit" => _audit_params} = req) do
    headers = [{"Content-Type", "application/json"}]
    body = req |> JSON.encode!
    HTTPoison.post!(get_audits_path(), body, headers, [])
  end

  defp get_config do
    Application.get_env(:td_dd, :audit_service)
  end

  defp get_audit_endpoint do
    audit_service_config = get_config()
    "#{audit_service_config[:protocol]}://#{audit_service_config[:audit_host]}:#{audit_service_config[:audit_port]}"
  end

  defp get_audits_path do
    audit_service_config = get_config()
    "#{get_audit_endpoint()}#{audit_service_config[:audits_path]}"
  end

end
