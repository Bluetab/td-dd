defmodule TdDd.Grants.Statuses do
  @moduledoc """
  The Grant Requests Statuses context.
  """

  alias Ecto.Multi
  alias TdDd.GrantRequests.Search.Indexer
  alias TdDd.Grants.Audit
  alias TdDd.Grants.GrantRequestStatus
  alias TdDd.Repo

  def create_grant_request_status(
        %{id: grant_request_id, current_status: current_status} = _grant_request,
        status,
        user_id,
        reason \\ nil
      ) do
    changeset =
      %GrantRequestStatus{
        user_id: user_id,
        previous_status: current_status,
        status: status,
        grant_request_id: grant_request_id,
        reason: reason
      }
      |> GrantRequestStatus.changeset(%{})

    Multi.new()
    |> Multi.insert(:grant_request_status, changeset)
    |> Multi.run(:audit, Audit, :grant_request_status_created, [])
    |> Repo.transaction()
    |> on_upsert()
  end

  defp on_upsert({:ok, %{grant_request_status: %{grant_request_id: grant_request_id}}} = result) do
    Indexer.reindex([grant_request_id])

    result
  end

  defp on_upsert(result), do: result
end
