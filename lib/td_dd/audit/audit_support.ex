defmodule TdDd.Audit.AuditSupport do
  @moduledoc """
  Support module for publishing audit events.
  """

  alias Ecto.Changeset
  alias TdCache.Audit
  alias TdDd.DataStructures.StructureNote
  alias TdDfLib.MapDiff
  alias TdDfLib.Masks

  def publish(events) when is_list(events) do
    Audit.publish_all(events)
  end

  def publish(event, resource_type, resource_id, user_id, payload \\ %{})

  def publish(event, resource_type, resource_id, user_id, %Changeset{changes: changes, data: data}) do
    if map_size(changes) == 0 do
      {:ok, :unchanged}
    else
      Audit.publish(
        event: event,
        resource_type: resource_type,
        resource_id: resource_id,
        user_id: user_id,
        payload: payload(changes, data)
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

  def publish(
        "structure_note_updated",
        resource_type,
        resource_id,
        user_id,
        %Changeset{changes: changes, data: data},
        event_payload
      ) do
    if map_size(changes) == 0 do
      {:ok, :unchanged}
    else
      Audit.publish(
        event: "structure_note_updated",
        resource_type: resource_type,
        resource_id: resource_id,
        user_id: user_id,
        payload: payload(changes, data) |> Map.merge(event_payload)
      )
    end
  end

  defp payload(
         %{df_content: new_content} = changes,
         %StructureNote{df_content: old_content} = _data
       ) do
    diff = MapDiff.diff(old_content, new_content, mask: &Masks.mask/1)
    domain_ids = Map.get(changes, :domain_ids, [])

    %{content: diff, domain_ids: domain_ids}
  end

  defp payload(%{df_content: new_content} = changes, %{df_content: old_content} = _data) do
    diff = MapDiff.diff(old_content, new_content, mask: &Masks.mask/1)

    changes
    |> Map.delete(:df_content)
    |> Map.put(:content, diff)
  end

  defp payload(changes, _data), do: changes
end
