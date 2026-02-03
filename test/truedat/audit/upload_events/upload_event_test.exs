defmodule Truedat.Audit.UploadEvents.UploadEventTest do
  use TdDd.DataCase

  alias Ecto.Changeset
  alias Truedat.Audit.UploadEvents.UploadEvent

  @unsafe "javascript:alert(document)"

  describe "changeset/2" do
    test "with valid data returns valid changeset" do
      %{id: job_id} = insert(:upload_job)

      params = %{
        job_id: job_id,
        status: "PENDING",
        response: %{message: "test"}
      }

      assert %Changeset{valid?: true} = UploadEvent.changeset(%UploadEvent{}, params)
    end

    test "validates required fields" do
      assert %Changeset{errors: errors} = UploadEvent.changeset(%UploadEvent{}, %{})

      assert {_, [validation: :required]} = errors[:job_id]
      assert {_, [validation: :required]} = errors[:status]
    end

    test "validates job_id is integer" do
      params = %{
        job_id: "not_an_integer",
        status: "PENDING"
      }

      assert %Changeset{valid?: false, errors: errors} =
               UploadEvent.changeset(%UploadEvent{}, params)

      assert {"is invalid", [type: :id, validation: :cast]} = errors[:job_id]
    end

    test "validates status is string" do
      %{id: job_id} = insert(:upload_job)

      params = %{
        job_id: job_id,
        status: true
      }

      assert %Changeset{valid?: false, errors: errors} =
               UploadEvent.changeset(%UploadEvent{}, params)

      assert {"is invalid", [type: :string, validation: :cast]} = errors[:status]
    end

    test "validates response is map" do
      %{id: job_id} = insert(:upload_job)

      params = %{
        job_id: job_id,
        status: "PENDING",
        response: "not_a_map"
      }

      assert %Changeset{valid?: false, errors: errors} =
               UploadEvent.changeset(%UploadEvent{}, params)

      assert {"is invalid", [type: :map, validation: :cast]} = errors[:response]
    end

    test "validates response is not a list" do
      %{id: job_id} = insert(:upload_job)

      params = %{
        job_id: job_id,
        status: "PENDING",
        response: ["not", "a", "map"]
      }

      assert %Changeset{valid?: false, errors: errors} =
               UploadEvent.changeset(%UploadEvent{}, params)

      assert {"is invalid", [type: :map, validation: :cast]} = errors[:response]
    end

    test "validates status inclusion" do
      %{id: job_id} = insert(:upload_job)

      params = %{
        job_id: job_id,
        status: "INVALID_STATUS"
      }

      assert %Changeset{valid?: false, errors: errors} =
               UploadEvent.changeset(%UploadEvent{}, params)

      assert {_, [validation: :inclusion, enum: _]} = errors[:status]
    end

    test "accepts valid status values" do
      %{id: job_id} = insert(:upload_job)

      for status <- ["PENDING", "FAILED", "STARTED", "COMPLETED", "ERROR", "INFO"] do
        params = %{
          job_id: job_id,
          status: status
        }

        assert %Changeset{valid?: true} = UploadEvent.changeset(%UploadEvent{}, params)
      end
    end

    test "allows nil response" do
      %{id: job_id} = insert(:upload_job)

      params = %{
        job_id: job_id,
        status: "PENDING",
        response: nil
      }

      assert %Changeset{valid?: true} = UploadEvent.changeset(%UploadEvent{}, params)
    end

    test "allows empty map response" do
      %{id: job_id} = insert(:upload_job)

      params = %{
        job_id: job_id,
        status: "PENDING",
        response: %{}
      }

      assert %Changeset{valid?: true} = UploadEvent.changeset(%UploadEvent{}, params)
    end

    test "validates safe response content" do
      %{id: job_id} = insert(:upload_job)

      params = %{
        job_id: job_id,
        status: "PENDING",
        response: %{message: "valid message"}
      }

      assert %Changeset{valid?: true} = UploadEvent.changeset(%UploadEvent{}, params)
    end

    test "detects unsafe content in response" do
      %{id: job_id} = insert(:upload_job)

      params = %{
        job_id: job_id,
        status: "PENDING",
        response: %{"text" => %{"value" => @unsafe, "origin" => "user"}}
      }

      assert %Changeset{valid?: false, errors: errors} =
               UploadEvent.changeset(%UploadEvent{}, params)

      assert errors[:response] == {"invalid content", []}
    end

    test "with existing struct updates fields" do
      event = insert(:upload_event)

      params = %{
        status: "COMPLETED",
        response: %{result: "success"}
      }

      changeset = UploadEvent.changeset(event, params)

      assert %Changeset{valid?: true, changes: changes} = changeset
      assert changes.status == "COMPLETED"
      assert changes.response == %{result: "success"}
    end
  end
end
