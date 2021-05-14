defmodule TdDd.DataStructures.Audit do
  @moduledoc """
  The Data Structures Audit context. The public functions in this module are designed to
  be called using `Ecto.Multi.run/5`, although the first argument (`repo`) is
  not currently used.
  """

  import TdDd.Audit.AuditSupport, only: [publish: 4, publish: 5]

  @doc """
  Publishes a `:data_structure_updated` event. Should be called using `Ecto.Multi.run/5`.
  """
  def data_structure_updated(_repo, %{data_structure: %{id: id}}, %{} = changeset, user_id) do
    publish("data_structure_updated", "data_structure", id, user_id, changeset)
  end

  @doc """
  Publishes a `:data_structure_deleted` event. Should be called using `Ecto.Multi.run/5`.
  """
  def data_structure_deleted(_repo, %{data_structure: %{id: id}}, user_id) do
    publish("data_structure_deleted", "data_structure", id, user_id)
  end

  @doc """
  Publishes `:data_structure_updated` events for all changed structures in a
  bulk updated. The first argument is a map with ids as keys and changesets as
  values. The second argument is the user_id who performed the bulk updated.
  """
  def data_structures_bulk_updated(changesets_by_id, user_id)

  def data_structures_bulk_updated(%{} = changesets_by_id, _user_id)
      when map_size(changesets_by_id) == 0 do
    {:ok, []}
  end

  def data_structures_bulk_updated(%{} = changesets_by_id, user_id) do
    changesets_by_id
    |> Enum.map(fn {id, changeset} ->
      publish("data_structure_updated", "data_structure", id, user_id, changeset)
    end)
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    |> case do
      %{error: errors} -> {:error, errors}
      %{ok: ids} -> {:ok, ids}
    end
  end

  @doc """
  Publishes `:tag_linked` events for all created links 
  between a structure and its tags.
  """
  def tag_linked(_repo, %{linked_tag: %{id: id} = payload}, user_id) do
    payload =
      payload
      |> with_structure(payload)
      |> with_tag(payload)
      |> Map.take([
        :id,
        :data_structure,
        :data_structure_id,
        :data_structure_tag,
        :data_structure_tag_id,
        :description,
        :inserted_at,
        :updated_at
      ])

    publish("tag_linked", "tag", id, user_id, payload)
  end

  @doc """
  Publishes `:tag_link_updated` events for all changed links 
  between a structure and its tags.
  """
  def tag_link_updated(_repo, %{linked_tag: %{id: id}}, %{} = changeset, user_id) do
    publish("tag_link_updated", "tag", id, user_id, changeset)
  end

  @doc """
  Publishes a `:tag_link_deleted` event. Should be called using `Ecto.Multi.run/5`.
  """
  def tag_link_deleted(_repo, %{deleted_link_tag: %{id: id}}, user_id) do
    publish("tag_link_deleted", "tag", id, user_id)
  end

  defp with_structure(payload, %{data_structure: data_structure}) do
    Map.put(payload, :data_structure, Map.take(data_structure, [:id, :external_id]))
  end

  defp with_tag(payload, %{data_structure_tag: data_structure_tag}) do
    Map.put(payload, :data_structure_tag, Map.take(data_structure_tag, [:id, :name]))
  end
end
