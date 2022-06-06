defmodule TdDq.Implementations.Workflow do
  @moduledoc """
  The Implementation Workflow context.
  """

  import Ecto.Query

  alias Ecto.Multi
  alias TdDd.Auth.Claims, as: TdDdClaims
  alias TdDd.Repo
  alias TdDq.Implementations.Implementation

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
         _claims
       ) do
    changeset = status_changeset(implementation, status)

    Multi.new()
    |> maybe_version_existing(implementation, status)
    |> Multi.update(:implementation, changeset)
    ### TODO: Audit events
    # |> Multi.run(:audit, Audit, audit_event, [changeset, user_id])
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
         %Implementation{id: id, implementation_key: key} = implementation,
         "published"
       ) do
    latest_version =
      Implementation
      |> where(implementation_key: ^key)
      |> where([i], i.id != ^id)
      |> select([i], i.version + 1)
      |> Repo.one()

    case latest_version do
      nil -> Implementation.status_changeset(implementation, %{status: "published", version: 1})
      v -> Implementation.status_changeset(implementation, %{status: "published", version: v})
    end
  end

  defp status_changeset(implementation, status),
    do: Implementation.status_changeset(implementation, %{status: status})

  defp maybe_version_existing(multi, %{implementation_key: key} = _implementation, "published") do
    queryable =
      Implementation
      |> where(status: :published)
      |> where(implementation_key: ^key)

    Multi.update_all(multi, :versioned, queryable,
      set: [updated_at: DateTime.utc_now(), status: :versioned]
    )
  end

  defp maybe_version_existing(multi, _, _not_published), do: multi

  defp on_upsert({:ok, %{implementation: %{id: id}}} = result) do
    @index_worker.reindex_implementations(id)
    result
  end

  defp on_upsert(result), do: result
end
