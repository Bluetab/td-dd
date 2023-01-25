defmodule TdDd.DataStructures.Audit do
  @moduledoc """
  The Data Structures Audit context. The public functions in this module are designed to
  be called using `Ecto.Multi.run/5`, although the first argument (`repo`) is
  not currently used.
  """

  import TdDd.Audit.AuditSupport, only: [publish: 1, publish: 4, publish: 5, publish: 6]

  alias Ecto.Changeset
  alias TdCache.TaxonomyCache
  alias TdDd.DataStructures.RelationTypes

  @doc """
  Publishes a `:structure_note_updated` event when modifying a StructureNote. Should be called using `Ecto.Multi.run/5`.
  """
  def structure_note_updated(
        _repo,
        %{structure_note: %{id: id} = structure_note, latest: latest} = multi,
        %{} = changeset,
        user_id
      ) do
    payload =
      structure_note
      |> with_resource(latest)
      |> with_domain_ids(structure_note)
      |> with_structure_id(structure_note)
      |> maybe_field_parent(multi)
      |> Map.take([
        :data_structure_id,
        :domain_ids,
        :resource,
        :field_parent_id
      ])

    publish(
      "structure_note_updated",
      "data_structure_note",
      id,
      user_id,
      changeset,
      payload
    )
  end

  @doc """
  Publishes a `:structure_note_status_updated` event when modifying status StructureNote. Should be called using `Ecto.Multi.run/5`.
  """
  def structure_note_status_updated(
        _repo,
        %{structure_note: %{id: id} = structure_note, latest: latest} = multi,
        status,
        user_id
      ) do
    payload =
      structure_note
      |> with_resource(latest)
      |> with_domain_ids(structure_note)
      |> with_structure_id(structure_note)
      |> maybe_field_parent(multi)
      |> Map.take([
        :data_structure_id,
        :domain_ids,
        :resource,
        :field_parent_id
      ])

    publish("structure_note_" <> status, "data_structure_note", id, user_id, payload)
  end

  @doc """
  Publishes a `:structure_note_deleted` event when deleted StructureNote. Should be called using `Ecto.Multi.run/5`.
  """
  def structure_note_deleted(
        _repo,
        %{structure_note: %{id: id} = structure_note, latest: latest} = multi,
        user_id
      ) do
    payload =
      structure_note
      |> with_resource(latest)
      |> with_domain_ids(structure_note)
      |> with_structure_id(structure_note)
      |> maybe_field_parent(multi)
      |> Map.take([
        :data_structure_id,
        :domain_ids,
        :resource,
        :field_parent_id
      ])

    publish("structure_note_deleted", "data_structure_note", id, user_id, payload)
  end

  @doc """
  Publishes a `:data_structure_updated` event. Should be called using `Ecto.Multi.run/5`.
  """
  def data_structure_updated(_repo, %{}, id, %{} = changeset, user_id) do
    publish("data_structure_updated", "data_structure", id, user_id, changeset)
  end

  @doc """
  Publishes a `:data_structure_deleted` event. Should be called using `Ecto.Multi.run/5`.
  """
  def data_structure_deleted(_repo, %{data_structure: %{id: id}}, user_id) do
    publish("data_structure_deleted", "data_structure", id, user_id)
  end

  def data_structure_deleted(
        _repo,
        %{descendents: %{data_structures_ids: structures_ids}},
        user_id
      ) do
    structures_ids
    |> Enum.map(&data_structure_deleted(&1, user_id))
    |> publish()
  end

  defp data_structure_deleted(id, user_id) when is_number(id) do
    %{
      event: "data_structure_deleted",
      resource_type: "data_structure",
      resource_id: id,
      user_id: user_id,
      payload: %{}
    }
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
  Publishes `:structure_tag_created` events for all created links
  between a structure and its tags.
  """
  def structure_tag_created(
        _repo,
        %{
          structure_tag: %{data_structure_id: id, tag: %{name: tag_name}} = structure_tag,
          latest: latest
        },
        user_id
      ) do
    payload =
      structure_tag
      |> with_resource(latest)
      |> with_domain_ids(structure_tag)
      |> Map.put(:tag, tag_name)
      |> Map.take([
        :id,
        :data_structure_id,
        :comment,
        :domain_ids,
        :inserted_at,
        :updated_at,
        :resource,
        :tag,
        :tag_id
      ])

    publish("structure_tag_linked", "data_structure", id, user_id, payload)
  end

  @doc """
  Publishes `:structure_tag_updated` events for all changed links
  between a structure and its tags.
  """
  def structure_tag_updated(
        _repo,
        %{
          structure_tag: %{data_structure_id: id, tag: %{name: tag_name}} = structure_tag,
          latest: latest
        },
        %{changes: changes},
        user_id
      ) do
    payload =
      changes
      |> with_resource(latest)
      |> with_domain_ids(structure_tag)
      |> Map.put(:tag, tag_name)

    publish("structure_tag_link_updated", "data_structure", id, user_id, payload)
  end

  @doc """
  Publishes a `:structure_tag_deleted` event. Should be called using `Ecto.Multi.run/5`.
  """
  def structure_tag_deleted(
        _repo,
        %{
          structure_tag: %{data_structure_id: id, tag: %{name: name}} = structure_tag,
          latest: latest
        },
        user_id
      ) do
    payload =
      structure_tag
      |> with_resource(latest)
      |> with_domain_ids(structure_tag)
      |> Map.put(:tag, name)
      |> Map.take([
        :id,
        :data_structure_id,
        :comment,
        :domain_ids,
        :inserted_at,
        :updated_at,
        :resource,
        :tag,
        :tag_id
      ])

    publish("structure_tag_link_deleted", "data_structure", id, user_id, payload)
  end

  @doc """
  Publishes a `:grant_created` event when creating a Grant. Should be called using `Ecto.Multi.run/5`.
  """
  def grant_created(_repo, %{grant: %{id: id} = grant, latest: latest}, user_id) do
    payload =
      grant
      |> with_resource(latest)
      |> with_domain_ids(grant)
      |> Map.take([
        :detail,
        :user_id,
        :end_date,
        :domain_ids,
        :start_date,
        :data_structure_id,
        :resource
      ])

    publish("grant_created", "grant", id, user_id, payload)
  end

  @doc """
  Publishes a `:grant_updated` event when updating a Grant. Should be called using `Ecto.Multi.run/5`.
  """
  def grant_updated(_repo, %{grant: %{id: id}}, %{} = changeset, user_id) do
    publish("grant_updated", "grant", id, user_id, changeset)
  end

  @doc """
  Publishes a `:grant_deleted` event when deleting a Grant. Should be called using `Ecto.Multi.run/5`.
  """
  def grant_deleted(_repo, %{grant: %{id: id} = grant, latest: latest}, user_id) do
    payload =
      grant
      |> with_resource(latest)
      |> with_domain_ids(grant)
      |> Map.take([
        :user_id,
        :end_date,
        :domain_ids,
        :start_date,
        :data_structure_id,
        :resource
      ])

    publish("grant_deleted", "grant", id, user_id, payload)
  end

  defp with_domain_ids(%Changeset{} = changeset, %{data_structure: %{domain_ids: domain_ids}}) do
    Changeset.put_change(changeset, :domain_ids, get_domain_ids(domain_ids))
  end

  defp with_domain_ids(%{domain_ids: acc_domain_ids} = payload, %{
         data_structure: %{domain_ids: domain_ids}
       }) do
    Map.put(payload, :domain_ids, acc_domain_ids ++ get_domain_ids(domain_ids))
  end

  defp with_domain_ids(%{} = payload, %{data_structure: %{domain_ids: domain_ids}}) do
    Map.put(payload, :domain_ids, get_domain_ids(domain_ids))
  end

  defp with_domain_ids(payload, _), do: payload

  defp with_structure_id(%{} = payload, %{data_structure_id: data_structure_id}) do
    Map.put(payload, :data_structure_id, data_structure_id)
  end

  defp get_domain_ids(nil), do: []
  defp get_domain_ids([]), do: []

  defp get_domain_ids(domain_ids) when is_list(domain_ids) do
    TaxonomyCache.reaching_domain_ids(domain_ids)
  end

  defp with_resource(%{} = payload, latest) do
    resource = build_resource(payload, latest)
    Map.put(payload, :resource, resource)
  end

  defp build_resource(%{data_structure: data_structure}, %{name: name} = latest) do
    path = Enum.map(latest.path, fn %{"name" => name} -> name end)

    %{
      external_id: data_structure.external_id,
      name: name,
      path: path
    }
  end

  defp build_resource(_, %{data_structure: data_structure} = latest) do
    build_resource(%{data_structure: data_structure}, latest)
  end

  defp build_resource(_payload, _latest), do: %{}

  defp maybe_field_parent(payload, %{
         latest: %{class: "field", parent_relations: [_ | _] = parent_relations}
       }) do
    relation_type_id = RelationTypes.default_id!()

    field_parent_id =
      parent_relations
      |> Enum.find(&(&1.relation_type_id == relation_type_id))
      |> case do
        %{parent: %{data_structure_id: parent_id}} -> parent_id
        _ -> nil
      end

    Map.put(payload, :field_parent_id, field_parent_id)
  end

  defp maybe_field_parent(payload, _), do: payload
end
