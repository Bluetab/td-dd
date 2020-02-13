defmodule TdCx.Sources.Jobs.JobTest do
  use TdCx.DataCase

  alias Elasticsearch.Document
  alias TdCx.Repo

  describe "Job" do
    test "encode/1 without events" do
      %{external_id: external_id, id: id, source: source} = job = insert(:job, events: [])

      assert Document.encode(job) == %{
               external_id: external_id,
               id: id,
               source: %{
                 external_id: source.external_id,
                 type: source.type
               },
               status: ""
             }
    end

    test "encode/1 with events" do
      job = insert(:job)

      Enum.each(["foo", "bar", "baz"], fn type ->
        insert(:event, type: type, job: job)
      end)

      job = Repo.preload(job, [:source, :events])
      assert %{status: "baz"} = Document.encode(job)
    end
  end
end
