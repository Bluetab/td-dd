defmodule TdDdWeb.ResponseCode do
  @moduledoc false

  @ok "Ok"
  @created "Created"
  @no_content "No Content"
  @forbidden "Forbidden"
  @unauthorized "Unauthorized"
  @not_found "NotFound"
  @unprocessable_entity "Unprocessable Entity"

  def rc_ok, do: @ok
  def rc_created, do: @created
  def rc_forbidden, do: @forbidden
  def rc_unauthorized, do: @unauthorized
  def rc_not_found, do: @not_found
  def rc_unprocessable_entity, do: @unprocessable_entity

  def to_response_code(http_status_code) do
    case http_status_code do
      200 -> @ok
      201 -> @created
      204 -> @no_content
      401 -> @unauthorized
      403 -> @forbidden
      404 -> @not_found
      422 -> @unprocessable_entity
      _ -> "Unknown: #{http_status_code}"
    end
  end
end
