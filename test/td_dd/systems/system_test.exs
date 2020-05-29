defmodule TdDd.Systems.SystemTest do
  use TdDd.DataCase

  alias TdDd.Repo
  alias TdDd.Systems.System

  describe "changeset/0" do
    test "detects missing required fields" do
      assert %{errors: errors} = System.changeset(%{})
      assert length(errors) == 2
      assert {_message, [validation: :required]} = errors[:external_id]
      assert {_message, [validation: :required]} = errors[:name]
    end

    test "detects unique constraint violation" do
      insert(:system, external_id: "foo")

      assert {:error, %{errors: errors}} =
               :system
               |> build(external_id: "foo")
               |> Map.take([:external_id, :name])
               |> System.changeset()
               |> Repo.insert()

      assert {_message, info} = errors[:external_id]
      assert info[:constraint] == :unique
    end
  end

  describe "changeset/1" do
    test "detects missing required fields" do
      system = insert(:system)
      assert %{errors: errors} = System.changeset(system, %{external_id: nil, name: nil})
      assert length(errors) == 2
      assert {_message, [validation: :required]} = errors[:external_id]
      assert {_message, [validation: :required]} = errors[:name]
    end

    test "detects unique constraint violation" do
      insert(:system, external_id: "foo")
      system = insert(:system, external_id: "bar")

      assert {:error, %{errors: errors}} =
               system
               |> System.changeset(%{external_id: "foo"})
               |> Repo.update()

      assert {_message, info} = errors[:external_id]
      assert info[:constraint] == :unique
    end
  end
end
