defmodule TdDd.Grants.StatusesTest do
  use TdDd.DataCase

  alias Ecto.Changeset
  alias TdDd.Grants.GrantRequestStatus
  alias TdDd.Grants.Statuses

  setup do
    [grant_request: insert(:grant_request, current_status: "approved")]
  end

  describe "Requests.create_grant_request_status/2" do
    test "fails with non valid current grant request status", %{grant_request: request} do
      assert {:error, %Changeset{errors: [status: {"invalid status change", _}]}} =
               Statuses.create_grant_request_status(request, "not_valid_status")
    end

    test "creates grant request status with valid status change", %{
      grant_request: %{id: id} = request
    } do
      assert {:ok, %GrantRequestStatus{grant_request_id: ^id, status: "processing"}} =
               Statuses.create_grant_request_status(request, "processing")
    end

    test "allows to create failed status with a reason if current is processing" do
      %{id: id} = request = insert(:grant_request, current_status: "processing")
      reason = "failed reason"

      assert {:ok, %GrantRequestStatus{grant_request_id: ^id, status: "failed", reason: ^reason}} =
               Statuses.create_grant_request_status(request, "failed", reason)
    end
  end
end
