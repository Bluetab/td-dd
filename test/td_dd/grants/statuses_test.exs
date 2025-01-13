defmodule TdDd.Grants.StatusesTest do
  use TdDd.DataCase

  alias Ecto.Changeset
  alias TdDd.Grants.GrantRequestStatus
  alias TdDd.Grants.Statuses

  alias TdCore.Search.IndexWorkerMock

  setup do
    IndexWorkerMock.clear()

    [grant_request: insert(:grant_request, current_status: "approved")]
  end

  describe "Requests.create_grant_request_status/2" do
    test "fails with non valid current grant request status", %{grant_request: request} do
      IndexWorkerMock.clear()

      assert {:error, :grant_request_status,
              %Changeset{errors: [status: {"invalid status change", _}]},
              _} = Statuses.create_grant_request_status(request, "not_valid_status", 0)

      assert IndexWorkerMock.calls() == []
    end

    test "creates grant request status with valid status change", %{
      grant_request: %{id: id} = request
    } do
      IndexWorkerMock.clear()

      assert {:ok,
              %{
                grant_request_status: %GrantRequestStatus{
                  grant_request_id: ^id,
                  status: "processing"
                }
              }} = Statuses.create_grant_request_status(request, "processing", 0)

      assert [{:reindex, :grant_requests, [^id]}] = IndexWorkerMock.calls()
    end

    test "allows to create failed status with a reason if current is processing" do
      IndexWorkerMock.clear()
      %{id: id} = request = insert(:grant_request, current_status: "processing")
      reason = "failed reason"

      assert {:ok,
              %{
                grant_request_status: %GrantRequestStatus{
                  grant_request_id: ^id,
                  status: "failed",
                  reason: ^reason
                }
              }} = Statuses.create_grant_request_status(request, "failed", 0, reason)

      assert [{:reindex, :grant_requests, [^id]}] = IndexWorkerMock.calls()
    end
  end
end
