defmodule TdDd.Grants.Statuses do
  @moduledoc """
  The Grant Requests Statuses context.
  """

  alias TdDd.Grants.GrantRequestStatus
  alias TdDd.Repo

  def create_grant_request_status(
        %{id: grant_request_id, current_status: current_status} = _grant_request,
        status
      ) do
    %GrantRequestStatus{
      previous_status: current_status,
      status: status,
      grant_request_id: grant_request_id
    }
    |> GrantRequestStatus.changeset(%{})
    |> Repo.insert()
  end
end
