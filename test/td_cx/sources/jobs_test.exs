defmodule TdCx.Sources.JobsTest do
  use TdCx.DataCase

  alias TdCx.Sources.Jobs

  describe "jobs" do
    alias TdCx.Sources.Jobs.Job

    test "create_job/1 with valid data creates a job" do
      source = insert(:source)
      assert {:ok, %Job{} = job} = Jobs.create_job(%{source_id: source.id})
      assert job.source_id == source.id
      assert not is_nil(job.external_id)
    end
  end
end
