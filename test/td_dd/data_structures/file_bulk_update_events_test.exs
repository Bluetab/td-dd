defmodule TdDd.DataStructures.FileBulkUpdateEventsTest do
  use TdDd.DataCase

  alias Ecto.Changeset
  alias TdDd.DataStructures.FileBulkUpdateEvent
  alias TdDd.DataStructures.FileBulkUpdateEvents

  setup do
    insert(:file_bulk_update_event,
      user_id: 1,
      hash: "hash_1",
      filename: "file_1.csv",
      inserted_at: ~U[2020-01-01 00:00:01Z]
    )

    insert(:file_bulk_update_event,
      user_id: 1,
      hash: "hash_1",
      filename: "file_1.csv",
      inserted_at: ~U[2020-01-02 00:00:01Z],
      status: "STARTED"
    )

    insert(:file_bulk_update_event,
      user_id: 2,
      hash: "hash_2",
      filename: "file_2.csv",
      inserted_at: ~U[2020-01-01 00:00:01Z]
    )

    insert(:file_bulk_update_event,
      user_id: 2,
      hash: "hash_2",
      filename: "file_2.csv",
      inserted_at: DateTime.utc_now(),
      status: "STARTED"
    )

    insert(:file_bulk_update_event,
      user_id: 2,
      hash: "hash_3",
      filename: "file_3.csv",
      inserted_at: ~U[2020-01-01 00:00:01Z]
    )

    insert(:file_bulk_update_event,
      user_id: 2,
      hash: "hash_3",
      filename: "file_3.csv",
      inserted_at: ~U[2020-01-02 00:00:01Z],
      status: "STARTED"
    )

    :ok
  end

  test "get_by_user_id" do
    assert [
             %FileBulkUpdateEvent{user_id: 1},
             %FileBulkUpdateEvent{user_id: 1}
           ] = FileBulkUpdateEvents.get_by_user_id(1)
  end

  test "last_event_by hash gets last event by hash" do
    assert %FileBulkUpdateEvent{
             hash: "hash_1",
             filename: "file_1.csv",
             inserted_at: ~U[2020-01-02 00:00:01.000000Z]
           } = FileBulkUpdateEvents.last_event_by_hash("hash_1")
  end

  test "last_event_by hash check_timeout inserts ALREADY_STARTED if timeout has not yet elapsed" do
    assert %FileBulkUpdateEvent{
             hash: "hash_2",
             filename: "file_2.csv",
             status: "ALREADY_STARTED"
           } = FileBulkUpdateEvents.last_event_by_hash("hash_2")
  end

  test "last_event_by hash check_timeout inserts TIMED_OUT if timeout has already elapsed" do
    assert %FileBulkUpdateEvent{
             hash: "hash_3",
             filename: "file_3.csv",
             status: "TIMED_OUT"
           } = FileBulkUpdateEvents.last_event_by_hash("hash_3")
  end

  describe "FileBulkUpdateEvents.create_event/2" do
    test "missing required parameter fails" do
      params = %{
        inserted_at: "2022-04-24T11:08:18.215905Z",
        message: nil,
        response: %{errors: [], ids: [1, 2]},
        status: "COMPLETED",
        task_reference: "0.262460172.3388211201.119663",
        user_id: 467
      }

      assert {
               :error,
               %Changeset{
                 errors: [
                   hash: {"can't be blank", [validation: :required]},
                   filename: {"can't be blank", [validation: :required]}
                 ]
               }
             } = FileBulkUpdateEvents.create_event(params)
    end
  end
end
