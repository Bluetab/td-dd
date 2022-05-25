defmodule TdDq.Implementations.Workflow do
  @moduledoc """
  The Implementation Workflow context.
  """

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

  def unreject_implementation(%Implementation{} = implementation, %TdDdClaims{} = claims) do
    update_implementation_status(
      implementation,
      "pending_approval",
      :implementation_pending_approval,
      claims
    )
  end

  def publish_implementation(%Implementation{} = implementation, %TdDdClaims{} = claims) do
    update_implementation_status(implementation, "published", :implementation_published, claims)
  end

  def deprecate_implementation(%Implementation{} = implementation, %TdDdClaims{} = claims) do
    update_implementation_status(implementation, "deprecated", :implementation_deprecated, claims)
  end

  def publish_implementation_from_draft(
        %Implementation{} = implementation,
        %TdDdClaims{} = claims
      ) do
    update_implementation_status(implementation, "published", :implementation_published, claims)
  end

  defp update_implementation_status(
         implementation,
         status,
         _audit_event,
         _claims
       ) do
    changeset = Implementation.status_changeset(implementation, status)

    Multi.new()
    |> Multi.update(:implementation, changeset)
    ### TODO: Audit events
    # |> Multi.run(:audit, Audit, audit_event, [changeset, user_id])
    |> Repo.transaction()
    |> on_upsert()
  end

  defp on_upsert({:ok, %{implementation: %{id: id}}} = result) do
    @index_worker.reindex_implementations(id)
    result
  end

  defp on_upsert(result), do: result
end
