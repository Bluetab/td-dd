defmodule TdCx.Jobs.AuditTest do
  use TdDd.DataCase

  alias TdCache.Redix
  alias TdCache.Redix.Stream
  alias TdCx.Jobs.Audit
  alias TdDd.Repo

  @stream TdCache.Audit.stream()

  setup_all do
    Redix.del!(@stream)
    :ok
  end

  setup do
    on_exit(fn -> Redix.del!(@stream) end)

    claims = build(:claims, role: "admin")
    job = insert(:job, events: [], type: "foo")
    [claims: claims, job: job]
  end

  describe "job_status_updated/4" do
    test "publishes an event", %{
      claims: %{user_id: user_id},
      job: %{
        id: job_id,
        source_id: source_id,
        external_id: external_id,
        source: %{external_id: source_external_id}
      }
    } do
      type = "SUCCEEDED"
      message = "Job completed"
      event = build(:event, job_id: job_id, message: message, type: type)

      assert {:ok, event_id} =
               Audit.job_status_updated(
                 Repo,
                 %{
                   event: event,
                   source_id: source_id,
                   external_id: external_id,
                   source_external_id: source_external_id
                 },
                 user_id
               )

      assert {:ok, [event]} = Stream.range(:redix, @stream, event_id, event_id, transform: :range)

      user_id = "#{user_id}"
      resource_id = "#{job_id}"
      event_type = "job_status_" <> String.downcase(type)

      assert %{
               event: ^event_type,
               payload: payload,
               resource_id: ^resource_id,
               resource_type: "jobs",
               service: "td_dd",
               ts: _ts,
               user_id: ^user_id
             } = event

      assert %{
               "source_id" => ^source_id,
               "message" => ^message,
               "external_id" => ^external_id,
               "source_external_id" => ^source_external_id
             } = Jason.decode!(payload)
    end
  end
end
