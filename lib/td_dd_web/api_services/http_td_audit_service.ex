defmodule TdDdWeb.ApiServices.HttpTdAuditService do
  @moduledoc false

  require Logger
  alias Poison, as: JSON

  def post_audits(%{"audit" => _audit_params} = req) do
    headers = [{"Content-Type", "application/json"}]
    body = req |> JSON.encode!
    case HTTPoison.post(get_audits_path(), body, headers, []) do
      {:ok, response = %HTTPoison.Response{status_code: 201}} ->
        response
      {:ok, _response = %HTTPoison.Response{status_code: 422}} ->
        Logger.error "Error 422 in audit service (maybe Redis service is down): post_audits function"
      {:error, _error} ->
        Logger.error "Unknown error in audit service (maybe is down): post_audits function"
    end
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
