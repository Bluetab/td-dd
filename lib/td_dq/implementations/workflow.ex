defmodule TdDq.Implementations.Workflow do
  @moduledoc """
  The Implementation Workflow context.
  """

  import Ecto.Query

  alias Ecto.Multi
  alias TdDd.Repo
  alias TdDq.Cache.ImplementationLoader
  alias TdDq.Implementations.Implementation
  alias TdDq.Rules.Audit

  alias TdCore.Search.IndexWorker

  @status_order "published, pending_approval, draft, rejected, deprecated, versioned"

  def get_workflow_status_order, do: @status_order

  def submit_implementation(%Implementation{} = implementation, %{} = claims) do
    update_implementation_status(
      implementation,
      "pending_approval",
      :implementation_pending_approval,
      claims
    )
  end

  def reject_implementation(%Implementation{} = implementation, %{} = claims) do
    update_implementation_status(implementation, "rejected", :implementation_rejected, claims)
  end

  def publish_implementation(%Implementation{} = implementation, %{} = claims) do
    update_implementation_status(implementation, "published", :implementation_published, claims)
  end

  def restore_implementation(%Implementation{} = implementation, %{} = claims) do
    update_implementation_status(implementation, "restored", :implementation_published, claims)
  end

  def deprecate_implementation(%Implementation{} = implementation, %{} = claims) do
    update_implementation_status(implementation, "deprecated", :implementation_deprecated, claims)
  end

  defp update_implementation_status(
         implementation,
         status,
         _audit_event,
         %{user_id: user_id}
       ) do
    changeset = status_changeset(implementation, status)

    Multi.new()
    |> maybe_version_existing(changeset, user_id)
    |> Multi.update(:implementation, changeset)
    |> Multi.run(:cache, ImplementationLoader, :maybe_update_implementation_cache, [])
    |> Multi.run(:audit, Audit, :implementation_status_updated, [changeset, user_id])
    |> Repo.transaction()
    |> on_upsert()
  end

  defp status_changeset(%Implementation{} = implementation, "deprecated") do
    Implementation.status_changeset(implementation, %{
      status: "deprecated",
      deleted_at: DateTime.utc_now()
    })
  end

  defp status_changeset(
         %Implementation{id: id, implementation_ref: implementation_ref} = implementation,
         "published"
       ) do
    latest_version =
      Implementation
      |> where(implementation_ref: ^implementation_ref)
      |> where([i], i.id != ^id)
      |> select([i], max(i.version) + 1)
      |> Repo.one()

    case latest_version do
      nil -> Implementation.status_changeset(implementation, %{status: "published", version: 1})
      v -> Implementation.status_changeset(implementation, %{status: "published", version: v})
    end
  end

  defp status_changeset(
         %Implementation{id: id, implementation_ref: implementation_ref} = implementation,
         "restored"
       ) do
    latest_version =
      Implementation
      |> where(implementation_ref: ^implementation_ref)
      |> where([i], i.id != ^id)
      |> select([i], max(i.version) + 1)
      |> Repo.one()

    case latest_version do
      nil ->
        Implementation.status_changeset(implementation, %{
          status: "published",
          version: 1,
          deleted_at: nil
        })

      v ->
        Implementation.status_changeset(implementation, %{
          status: "published",
          version: v,
          deleted_at: nil
        })
    end
  end

  defp status_changeset(implementation, status),
    do: Implementation.status_changeset(implementation, %{status: status})

  def maybe_version_existing(
        multi,
        %{
          data: %{implementation_ref: implementation_ref} = implementation,
          changes: %{status: :published}
        },
        user_id
      ) do
    queryable =
      Implementation
      |> where(status: :published)
      |> where(implementation_ref: ^implementation_ref)
      |> select([i], i.id)

    Multi.update_all(multi, :versioned, queryable,
      set: [updated_at: DateTime.utc_now(), status: :versioned]
    )
    |> Multi.run(:audit_versioned, Audit, :implementation_versioned, [implementation, user_id])
  end

  def maybe_version_existing(multi, _changeset, _user_id), do: multi

  defp on_upsert({:ok, %{versioned: {_count, ids}, implementation: %{id: id}}} = result) do
    IndexWorker.reindex(:implementations, [id | ids])
    result
  end

  defp on_upsert({:ok, %{implementation: %{id: id}}} = result) do
    IndexWorker.reindex(:implementations, [id])
    result
  end

  defp on_upsert(result), do: result
end
