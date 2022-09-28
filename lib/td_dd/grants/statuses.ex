defmodule TdDd.Grants.Statuses do
  @moduledoc """
  The Grant Requests Statuses context.
  """

  alias Ecto.Multi

  alias TdDd.Grants.GrantRequestStatus
  alias TdDd.Grants.Audit
  alias TdDd.Repo

  def create_grant_request_status(
        %{id: grant_request_id, current_status: current_status} = _grant_request,
        status,
        user_id,
        reason \\ nil
      ) do
    changeset = %GrantRequestStatus{
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
  end
end
