defmodule TdDq.Implementations.Workflow do
  @moduledoc """
  The Implementation Workflow context.
  """

  import Ecto.Query

  alias Ecto.Multi
  alias TdDd.Auth.Claims, as: TdDdClaims
  alias TdDd.Repo
  alias TdDq.Implementations.Implementation
  alias TdDq.Rules.Audit

  @index_worker Application.compile_env(:td_dd, :dq_index_worker)

  def submit_implementation(%Implementation{} = implementation, %TdDdClaims{} = claims) do
    update_implementation_status(
      implementation,
      "pending_approval",
      :implementation_pending_approval,
      claims
    )
  end

  def reject_implementation(%Implementation{} = implementation, %TdDdClaims{} = claims) do
    update_implementation_status(implementation, "rejected", :implementation_rejected, claims)
  end

  def publish_implementation(%Implementation{} = implementation, %TdDdClaims{} = claims) do
    update_implementation_status(implementation, "published", :implementation_published, claims)
  end

  def deprecate_implementation(%Implementation{} = implementation, %TdDdClaims{} = claims) do
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
    |> maybe_version_existing(implementation, status, user_id)
    |> Multi.update(:implementation, changeset)
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

  defp status_changeset(implementation, status),
    do: Implementation.status_changeset(implementation, %{status: status})

  def maybe_version_existing(
        multi,
        %{implementation_ref: implementation_ref} = implementation,
        "published",
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

  def maybe_version_existing(multi, _, _not_published, _user_id), do: multi

  defp on_upsert({:ok, %{versioned: {_count, ids}, implementation: %{id: id}}} = result) do
    @index_worker.reindex_implementations([id | ids])
    result
  end

  defp on_upsert({:ok, %{implementation: %{id: id}}} = result) do
    @index_worker.reindex_implementations(id)
    result
  end

  defp on_upsert(result), do: result
end
