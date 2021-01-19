defmodule TdCx.Jobs.JobTest do
  use TdCx.DataCase

  alias Elasticsearch.Document
  alias TdCx.Repo

  describe "Job" do
    test "encode/1 without events" do
      %{external_id: external_id, id: id, source: source} =
        job = insert(:job, events: [], type: "foo")

      assert Document.encode(job) == %{
               external_id: external_id,
               id: id,
               source: %{
                 external_id: source.external_id,
                 type: source.type
               },
               status: "PENDING",
               type: "foo"
             }
    end

    test "encode/1 with events" do
      job = insert(:job)
      now = DateTime.utc_now()

      Enum.each(1..3, fn i ->
        insert(:event, type: "type_#{i}", job: job, inserted_at: DateTime.add(now, i))
      end)

      job = Repo.preload(job, [:source, :events])
      assert %{status: "type_3"} = Document.encode(job)
    end
  end
end
