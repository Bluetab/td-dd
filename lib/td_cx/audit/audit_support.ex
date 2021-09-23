defmodule TdCx.Audit.AuditSupport do
  @moduledoc """
  Support module for publishing audit events
  """

  alias TdCache.Audit

  def publish(event, resource_type, resource_id, user_id, payload \\ %{})

  def publish(event, resource_type, resource_id, user_id, payload) do
    Audit.publish(
      event: event,
      resource_type: resource_type,
      resource_id: resource_id,
      user_id: user_id,
      payload: payload
    )
  end
end
