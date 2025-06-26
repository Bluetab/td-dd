defmodule TdDq.Audit.AuditSupport do
  @moduledoc """
  Support module for publishing audit events.
  """

  alias TdCache.Audit
  alias TdDfLib.MapDiff
  alias TdDfLib.Masks
  alias TdDq.Implementations.Implementation

  def publish(events) when is_list(events) do
    Audit.publish_all(events)
  end

  def publish(event, resource_type, resource_id, user_id, payload \\ %{})

  def publish(
        event,
        resource_type,
        resource_id,
        user_id,
        %{changes: changes, data: data} = payload
      ) do
    if map_size(changes) == 0 do
      {:ok, :unchanged}
    else
      payload =
        changes
        |> payload(data)
        |> maybe_put_domain_updated(payload)

      Audit.publish(
        event: event,
        resource_type: resource_type,
        resource_id: resource_id,
        user_id: user_id,
        payload: payload
      )
    end
  end

  def publish(event, resource_type, resource_id, user_id, payload) do
    Audit.publish(
      event: event,
      resource_type: resource_type,
      resource_id: resource_id,
      user_id: user_id,
      payload: payload
    )
  end

  defp payload(%{df_content: new_content}, %Implementation{df_content: old_content} = _data) do
    diff = MapDiff.diff(old_content, new_content, mask: &Masks.mask/1)
    %{df_content: diff}
  end

  defp payload(%{df_content: new_content} = changes, %{df_content: old_content} = _data) do
    diff = MapDiff.diff(old_content, new_content, mask: &Masks.mask/1)

    changes
    |> Map.delete(:df_content)
    |> Map.put(:content, diff)
  end

  defp payload(changes, _data), do: changes

  defp maybe_put_domain_updated(
         changes,
         %{new_domain: new_domain, old_domain: old_domain}
       ) do
    changes
    |> Map.put(:old_domain, old_domain)
    |> Map.put(:new_domain, new_domain)
  end

  defp maybe_put_domain_updated(changes, _), do: changes
end
