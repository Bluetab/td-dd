defmodule TdDd.ProfilingLoaderTest do
  use TdDd.DataCase

  alias TdDd.DataStructures
  alias TdDd.ProfilingLoader
  alias TdDd.Utils.CollectionUtils

  describe "loader" do
    test "load/1 loads changes in data profiles" do
      sys1 = insert(:system, external_id: "SYS1", name: "SYS1")

      ds1 = insert(:data_structure, external_id: "DS1", system_id: sys1.id)
      ds2 = insert(:data_structure, external_id: "DS2", system_id: sys1.id)

      pr1 = insert(:profile, data_structure: ds1)

      attrs1 = %{external_id: "DS1", nullable: true, mode: "bar"}
      attrs2 = %{external_id: "DS2", nullable: true, mode: "bar"}

      assert {:ok, profile_ids} = ProfilingLoader.load([attrs1, attrs2])

      profiles = Enum.map(profile_ids, &DataStructures.get_profile!(&1))

      assert Enum.count(profiles) == 2

      assert attrs1 |> Map.take([:nullable, :mode]) |> CollectionUtils.stringify_keys() ==
               Enum.find(profiles, fn %{id: id} -> pr1.id == id end).value

      assert attrs2 |> Map.take([:nullable, :mode]) |> CollectionUtils.stringify_keys() ==
               Enum.find(profiles, fn %{data_structure_id: id} -> ds2.id == id end).value
    end

    test "load/1 error when data structure does not exist" do
      external_id = "DS1"
      attrs1 = %{external_id: external_id, nullable: true, mode: "bar"}
      assert {:error, error} = ProfilingLoader.load([attrs1])
      assert Map.get(error, :error) == "Missing structure with external_id #{external_id}"
    end
  end
end
