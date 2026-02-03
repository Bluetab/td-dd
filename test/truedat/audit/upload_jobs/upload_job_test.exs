defmodule Truedat.Audit.UploadJobs.UploadJobTest do
  use TdDd.DataCase

  alias Ecto.Changeset
  alias Truedat.Audit.UploadJobs.UploadJob

  describe "changeset/2" do
    test "with valid data returns valid changeset" do
      params = %{
        user_id: 1,
        hash: "hash123",
        filename: "test.xlsx",
        scope: "implementations"
      }

      assert %Changeset{valid?: true} = UploadJob.changeset(%UploadJob{}, params)
    end

    test "validates required fields" do
      assert %Changeset{errors: errors} = UploadJob.changeset(%UploadJob{}, %{})

      assert {_, [validation: :required]} = errors[:user_id]
      assert {_, [validation: :required]} = errors[:hash]
      assert {_, [validation: :required]} = errors[:filename]
    end

    test "validates user_id is integer" do
      params = %{
        user_id: "not_an_integer",
        hash: "hash123",
        filename: "test.xlsx"
      }

      assert %Changeset{valid?: false, errors: errors} =
               UploadJob.changeset(%UploadJob{}, params)

      assert {"is invalid", [type: :integer, validation: :cast]} = errors[:user_id]
    end

    test "validates hash is string" do
      params = %{
        user_id: 1,
        hash: true,
        filename: "test.xlsx"
      }

      assert %Changeset{valid?: false, errors: errors} =
               UploadJob.changeset(%UploadJob{}, params)

      assert {"is invalid", [type: :string, validation: :cast]} = errors[:hash]
    end

    test "validates filename is string" do
      params = %{
        user_id: 1,
        hash: "hash123",
        filename: []
      }

      assert %Changeset{valid?: false, errors: errors} =
               UploadJob.changeset(%UploadJob{}, params)

      assert {"is invalid", [type: :string, validation: :cast]} = errors[:filename]
    end

    test "validates scope inclusion" do
      params = %{
        user_id: 1,
        hash: "hash123",
        filename: "test.xlsx",
        scope: "invalid_scope"
      }

      assert %Changeset{valid?: false, errors: errors} =
               UploadJob.changeset(%UploadJob{}, params)

      assert {_, [validation: :inclusion, enum: _]} = errors[:scope]
    end

    test "accepts valid scope values" do
      for scope <- ["implementations", "notes"] do
        params = %{
          user_id: 1,
          hash: "hash123",
          filename: "test.xlsx",
          scope: scope
        }

        assert %Changeset{valid?: true} = UploadJob.changeset(%UploadJob{}, params)
      end
    end

    test "allows nil scope" do
      params = %{
        user_id: 1,
        hash: "hash123",
        filename: "test.xlsx",
        scope: nil
      }

      assert %Changeset{valid?: true} = UploadJob.changeset(%UploadJob{}, params)
    end

    test "with existing struct updates fields" do
      job = insert(:upload_job)

      params = %{
        user_id: 999,
        hash: "new_hash",
        filename: "new_file.xlsx"
      }

      changeset = UploadJob.changeset(job, params)

      assert %Changeset{valid?: true, changes: changes} = changeset
      assert changes.user_id == 999
      assert changes.hash == "new_hash"
      assert changes.filename == "new_file.xlsx"
    end
  end
end
