defmodule TdDd.SystemsTest do
  use TdDd.DataCase

  alias TdCache.Redix
  alias TdCache.Redix.Stream
  alias TdDd.Cache.SystemLoader
  alias TdDd.Systems

  @stream TdCache.Audit.stream()

  setup_all do
    start_supervised(SystemLoader)
    Redix.del!(@stream)
    :ok
  end

  setup do
    on_exit(fn -> Redix.del!(@stream) end)

    user = build(:user, is_admin: true)
    [user: user, system: insert(:system)]
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
    test "creates a system with valid data", %{user: user} do
      %{name: name, external_id: external_id} =
        params = :system |> build() |> Map.take([:external_id, :name])

      assert {:ok, %{system: system}} = Systems.create_system(params, user)
      assert %{external_id: ^external_id, name: ^name} = system
    end

    test "emits an audit event", %{user: user} do
      params = :system |> build() |> Map.take([:external_id, :name])

      assert {:ok, %{audit: event_id}} = Systems.create_system(params, user)
      assert {:ok, [%{id: ^event_id}]} = Stream.read(:redix, @stream, transform: true)
    end

    test "returns error changeset with invalid data", %{user: user} do
      assert {:error, :system, %Ecto.Changeset{}, %{}} = Systems.create_system(%{}, user)
    end
  end

  describe "update_system/3" do
    test "updates the system with valid data", %{system: system, user: user} do
      %{name: name, external_id: external_id} =
        params = :system |> build() |> Map.take([:external_id, :name])

      assert {:ok, %{system: system}} = Systems.update_system(system, params, user)
      assert %{external_id: ^external_id, name: ^name} = system
    end

    test "emits an audit event", %{system: system, user: user} do
      params = :system |> build() |> Map.take([:external_id, :name])
      assert {:ok, %{audit: event_id}} = Systems.update_system(system, params, user)
      assert {:ok, [%{id: ^event_id}]} = Stream.range(:redix, @stream, event_id, event_id, transform: :range)
    end

    test "returns error changeset with invalid data", %{system: system, user: user} do
      assert {:error, :system, %Ecto.Changeset{}, _} =
               Systems.update_system(system, %{name: nil}, user)
    end
  end

  describe "delete_system/2" do
    test "deletes the system", %{system: system, user: user} do
      assert {:ok, %{system: system}} = Systems.delete_system(system, user)
      assert %{__meta__: %{state: :deleted}} = system
    end

    test "emits an audit event", %{system: system, user: user} do
      assert {:ok, %{audit: event_id}} = Systems.delete_system(system, user)
      assert {:ok, [%{id: ^event_id}]} = Stream.range(:redix, @stream, event_id, event_id, transform: :range)
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
