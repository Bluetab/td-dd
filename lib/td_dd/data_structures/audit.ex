defmodule TdDd.DataStructures.Audit do
  @moduledoc """
  The Data Structures Audit context. The public functions in this module are designed to
  be called using `Ecto.Multi.run/5`, although the first argument (`repo`) is
  not currently used.
  """

  import TdDd.Audit.AuditSupport, only: [publish: 4, publish: 5]

  alias Ecto.Changeset
  alias TdCache.TaxonomyCache

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
  def tag_linked(
        _repo,
        %{
          linked_tag: %{data_structure_id: id, data_structure_tag: %{name: name}} = tag,
          latest: latest
        },
        user_id
      ) do
    payload =
      tag
      |> with_resource(latest)
      |> with_domain_ids(tag)
      |> Map.put(:tag, name)
      |> Map.take([
        :id,
        :data_structure_id,
        :data_structure_tag_id,
        :description,
        :domain_ids,
        :inserted_at,
        :updated_at,
        :resource,
        :tag
      ])

    publish("structure_tag_linked", "data_structure", id, user_id, payload)
  end

  @doc """
  Publishes `:tag_link_updated` events for all changed links
  between a structure and its tags.
  """
  def tag_link_updated(
        _repo,
        %{
          linked_tag: %{data_structure_id: id, data_structure_tag: %{name: name}} = tag,
          latest: latest
        },
        %{} = changeset,
        user_id
      ) do
    changeset =
      changeset
      |> with_resource(tag, latest)
      |> with_domain_ids(tag)
      |> Changeset.put_change(:tag, name)

    publish("structure_tag_link_updated", "data_structure", id, user_id, changeset)
  end

  @doc """
  Publishes a `:tag_link_deleted` event. Should be called using `Ecto.Multi.run/5`.
  """
  def tag_link_deleted(
        _repo,
        %{
          deleted_link_tag: %{data_structure_id: id, data_structure_tag: %{name: name}} = tag,
          latest: latest
        },
        user_id
      ) do
    payload =
      tag
      |> with_resource(latest)
      |> with_domain_ids(tag)
      |> Map.put(:tag, name)
      |> Map.take([
        :id,
        :data_structure_id,
        :data_structure_tag_id,
        :description,
        :domain_ids,
        :inserted_at,
        :updated_at,
        :resource,
        :tag
      ])

    publish("structure_tag_link_deleted", "data_structure", id, user_id, payload)
  end

  defp with_domain_ids(%Changeset{} = changeset, %{data_structure: %{domain_id: domain_id}}) do
    domain_ids =
      domain_id
      |> TaxonomyCache.get_parent_ids()
      |> Enum.filter(& &1)

    Changeset.put_change(changeset, :domain_ids, domain_ids)
  end

  defp with_domain_ids(%{} = payload, %{data_structure: %{domain_id: domain_id}}) do
    domain_ids =
      domain_id
      |> TaxonomyCache.get_parent_ids()
      |> Enum.filter(& &1)

    Map.put(payload, :domain_ids, domain_ids)
  end

  defp with_resource(%{} = payload, latest) do
    resource = build_resource(payload, latest)
    Map.put(payload, :resource, resource)
  end

  defp with_resource(%Changeset{} = changeset, structure, latest) do
    resource = build_resource(structure, latest)
    Changeset.put_change(changeset, :resource, resource)
  end

  defp build_resource(%{data_structure: data_structure}, %{} = latest) do
    path = Enum.map(latest.path, fn %{"name" => name} -> name end)

    %{}
    |> Map.put(:external_id, data_structure.external_id)
    |> Map.put(:name, latest.name)
    |> Map.put(:path, path)
  end

  defp build_resource(_tag, _latest), do: %{}
end
