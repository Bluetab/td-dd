defmodule TdDd.SystemsTest do
  use TdDd.DataCase

  alias TdDd.Systems
  alias TdDd.Systems.System

  setup do
    [system: insert(:system)]
  end

  describe "list_systems/0" do
    test "returns all systems", %{system: system} do
      assert Systems.list_systems() == [system]
    end
  end

  describe "get_system/1" do
    test "returns the system with given id", %{system: system} do
      assert Systems.get_system(system.id) == {:ok, system}
    end

    test "returns error if system is not found" do
      assert Systems.get_system(-1) == {:error, :not_found}
    end
  end

  describe "create_system/2" do
    test "creates a system with valid data" do
      %{name: name, external_id: external_id} =
        params = :system |> build() |> Map.take([:external_id, :name])

      assert {:ok, %System{} = system} = Systems.create_system(params)
      assert %{external_id: ^external_id, name: ^name} = system
    end

    test "returns error changeset with invalid data" do
      assert {:error, %Ecto.Changeset{}} = Systems.create_system(%{})
    end
  end

  describe "update_system/3" do
    test "updates the system with valid data", %{system: system} do
      %{name: name, external_id: external_id} =
        params = :system |> build() |> Map.take([:external_id, :name])

      assert {:ok, %System{} = system} = Systems.update_system(system, params)
      assert %{external_id: ^external_id, name: ^name} = system
    end

    test "returns error changeset with invalid data", %{system: system} do
      assert {:error, %Ecto.Changeset{}} =
               Systems.update_system(system, %{name: nil})
    end
  end

  describe "delete_system/1" do
    test "deletes the system", %{system: system} do
      assert {:ok, %System{} = system} = Systems.delete_system(system)
      assert %{__meta__: %{state: :deleted}} = system
    end
  end

  describe "get_by/1" do
    test "gets the system by external_id", %{system: system} do
      assert Systems.get_by(external_id: system.external_id) == system
    end

    test "gets the system by name", %{system: system} do
      assert Systems.get_by(name: system.name) == system
    end
  end
end
