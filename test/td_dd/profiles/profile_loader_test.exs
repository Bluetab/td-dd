defmodule TdDd.Profiles.ProfileLoaderTest do
  use TdDd.DataCase

  alias TdDd.Profiles
  alias TdDd.Profiles.ProfileLoader

  setup do
    start_supervised!(TdCore.Search.Cluster)
    start_supervised!(TdCore.Search.IndexWorker)
    :ok
  end

  describe "TdDd.Profiles.ProfileLoader" do
    test "load/1 loads changes in data profiles" do
      sys1 = insert(:system, external_id: "SYS1", name: "SYS1")

      ds1 = insert(:data_structure, external_id: "DS1", system_id: sys1.id)
      ds2 = insert(:data_structure, external_id: "DS2", system_id: sys1.id)

      pr1 = insert(:profile, data_structure: ds1)

      attrs1 = %{external_id: "DS1", value: %{"null" => "0.01", "mode" => "foo"}}
      attrs2 = %{external_id: "DS2", value: %{"null" => "0.02", "mode" => "bar"}}

      assert {:ok, profile_ids} = ProfileLoader.load([attrs1, attrs2])

      profiles = Enum.map(profile_ids, &Profiles.get_profile!(&1))

      assert Enum.count(profiles) == 2

      assert attrs1.value ==
               Enum.find(profiles, fn %{id: id} -> pr1.id == id end).value

      assert attrs2.value ==
               Enum.find(profiles, fn %{data_structure_id: id} -> ds2.id == id end).value
    end

    test "load/1 error when data structure does not exist" do
      external_id = "DS1"
      attrs1 = %{external_id: external_id, nullable: true, mode: "bar"}
      assert {:error, _error} = ProfileLoader.load([attrs1])
    end

    test "load/1 error when missing params" do
      external_id = "DS1"
      sys1 = insert(:system, external_id: "SYS1", name: "SYS1")
      insert(:data_structure, external_id: external_id, system_id: sys1.id)
      attrs1 = %{external_id: external_id}
      assert {:error, _error} = ProfileLoader.load([attrs1])
    end
  end
end
