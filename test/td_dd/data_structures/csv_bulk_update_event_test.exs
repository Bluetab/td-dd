defmodule TdDd.DataStructures.CsvBulkUpdateEventTest do
  use TdDd.DataCase

  alias Ecto.Changeset
  alias TdDd.DataStructures.CsvBulkUpdateEvent

  @valid_attrs %{
    csv_hash: "47D90FDF1AD967BD7DBBDAE28664278E",
    inserted_at: "2022-04-24T11:08:18.215905Z",
    message: nil,
    response: %{errors: [], ids: [1, 2]},
    status: "COMPLETED",
    task_reference: "0.262460172.3388211201.119663",
    user_id: 467,
    filename: "foo"
  }

  describe "changeset/0" do
    test "valid changeset" do
      assert %Changeset{valid?: true} = CsvBulkUpdateEvent.changeset(@valid_attrs)
    end

    test "detects missing required fields" do
      assert %Changeset{errors: errors} = CsvBulkUpdateEvent.changeset(%{})

      assert ^errors = [
               user_id: {"can't be blank", [validation: :required]},
               csv_hash: {"can't be blank", [validation: :required]},
               task_reference: {"can't be blank", [validation: :required]},
               status: {"can't be blank", [validation: :required]}
             ]
    end

    test "puts node" do
      assert %Changeset{changes: %{node: _node}} = CsvBulkUpdateEvent.changeset(@valid_attrs)
    end
  end

  describe "changeset/1" do
    test "detects missing required fields" do
      event = insert(:csv_bulk_update_event, user_id: 1, csv_hash: "some_hash")

      assert %Changeset{errors: errors} =
               CsvBulkUpdateEvent.changeset(event, %{
                 task_reference: nil,
                 status: nil
               })

      assert ^errors = [
               task_reference: {"can't be blank", [validation: :required]},
               status: {"can't be blank", [validation: :required]}
             ]
    end
  end
end
