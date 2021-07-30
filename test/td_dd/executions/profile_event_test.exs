defmodule TdDd.Executions.ProfileEventTest do
  @moduledoc false
  use TdDd.DataCase

  alias TdDd.Executions.ProfileEvent
  alias TdDd.Repo

  describe "create_changeset/1" do
    test "validates required fields" do
      assert %{errors: errors} = ProfileEvent.create_changeset(%{})

      assert {_, [validation: :required]} = errors[:profile_execution_id]
    end

    test "returns changeset when fields are valid" do
      %{id: id} = insert(:profile_execution)

      assert {:ok,
              %{
                profile_execution_id: ^id,
                message: "foo",
                type: "bar"
              }} =
               %{profile_execution_id: id, message: "foo", type: "bar"}
               |> ProfileEvent.create_changeset()
               |> Repo.insert()
    end

    test "validates message size" do
      message = String.duplicate("foo", 334)
      %{id: id} = insert(:profile_execution)

      assert %{errors: errors} =
               ProfileEvent.create_changeset(%{
                 profile_execution_id: id,
                 message: message,
                 type: "bar"
               })

      assert {_, [count: 1000, validation: :length, kind: :max, type: :string]} = errors[:message]
    end
  end

  describe "changeset/2" do
    test "returns changeset when fields are valid" do
      %{id: id} = insert(:profile_execution)

      assert {:ok,
              %{
                profile_execution_id: ^id,
                message: "foo",
                type: "bar"
              }} =
               %{profile_execution_id: id, message: "foo", type: "bar"}
               |> ProfileEvent.changeset()
               |> Repo.insert()
    end

    test "validates message size" do
      message = String.duplicate("foo", 334)
      %{id: id} = insert(:profile_execution)

      assert %{errors: errors} =
               ProfileEvent.changeset(%{
                 profile_execution_id: id,
                 message: message,
                 type: "bar"
               })

      assert {_, [count: 1000, validation: :length, kind: :max, type: :string]} = errors[:message]
    end
  end
end
