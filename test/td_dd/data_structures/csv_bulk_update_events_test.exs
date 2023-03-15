defmodule TdDd.DataStructures.CsvBulkUpdateEventsTest do
  use TdDd.DataCase

  alias Ecto.Changeset
  alias TdDd.DataStructures.CsvBulkUpdateEvent
  alias TdDd.DataStructures.CsvBulkUpdateEvents

  setup do
    insert(:csv_bulk_update_event,
      user_id: 1,
      csv_hash: "hash_1",
      inserted_at: ~U[2020-01-01 00:00:01Z]
    )

    insert(:csv_bulk_update_event,
      user_id: 1,
      csv_hash: "hash_1",
      inserted_at: ~U[2020-01-02 00:00:01Z],
      status: "STARTED"
    )

    insert(:csv_bulk_update_event,
      user_id: 2,
      csv_hash: "hash_2",
      inserted_at: ~U[2020-01-01 00:00:01Z]
    )

    insert(:csv_bulk_update_event,
      user_id: 2,
      csv_hash: "hash_2",
      inserted_at: DateTime.utc_now(),
      status: "STARTED"
    )

    insert(:csv_bulk_update_event,
      user_id: 2,
      csv_hash: "hash_3",
      inserted_at: ~U[2020-01-01 00:00:01Z]
    )

    insert(:csv_bulk_update_event,
      user_id: 2,
      csv_hash: "hash_3",
      inserted_at: ~U[2020-01-02 00:00:01Z],
      status: "STARTED"
    )

    :ok
  end

  test "get_by_user_id" do
    assert [
             %CsvBulkUpdateEvent{user_id: 1},
             %CsvBulkUpdateEvent{user_id: 1}
           ] = CsvBulkUpdateEvents.get_by_user_id(1)
  end

  test "last_event_by hash gets last event by hash" do
    assert %CsvBulkUpdateEvent{csv_hash: "hash_1", inserted_at: ~U[2020-01-02 00:00:01.000000Z]} =
             CsvBulkUpdateEvents.last_event_by_hash("hash_1")
  end

  test "last_event_by hash check_timeout inserts ALREADY_STARTED if timeout has not yet elapsed" do
    assert %CsvBulkUpdateEvent{csv_hash: "hash_2", status: "ALREADY_STARTED"} =
             CsvBulkUpdateEvents.last_event_by_hash("hash_2")
  end

  test "last_event_by hash check_timeout inserts TIMED_OUT if timeout has already elapsed" do
    assert %CsvBulkUpdateEvent{csv_hash: "hash_3", status: "TIMED_OUT"} =
             CsvBulkUpdateEvents.last_event_by_hash("hash_3")
  end

  describe "CsvBulkUpdateEvents.create_event/2" do
    test "missing required parameter fails" do
      params = %{
        inserted_at: "2022-04-24T11:08:18.215905Z",
        message: nil,
        response: %{errors: [], ids: [1, 2]},
        status: "COMPLETED",
        task_reference: "0.262460172.3388211201.119663",
        user_id: 467,
        filename: "foo"
      }

      assert {:error, %Changeset{errors: [csv_hash: {"can't be blank", [validation: :required]}]}} =
               CsvBulkUpdateEvents.create_event(params)
    end
  end
end
