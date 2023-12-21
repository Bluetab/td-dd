defmodule TdDd.DataStructures.ProfilesTest do
  use TdDd.DataStructureCase

  import TdDd.TestOperators

  alias TdDd.Executions
  alias TdDd.Profiles
  alias TdDd.Profiles.Profile

  setup do
    start_supervised!(TdCore.Search.Cluster)
    start_supervised!(TdCore.Search.IndexWorker)
    :ok
  end

  describe "TdDd.Profiles" do
    @valid_attrs %{value: %{}, data_structure_id: 0}
    @update_attrs %{value: %{"foo" => "bar"}}
    @invalid_attrs %{value: nil, data_structure_id: nil}

    setup do
      profile = insert(:profile)
      [profile: profile]
    end

    test "get_profile!/1 gets the profile", %{profile: %{id: id}} do
      assert %{id: ^id} = Profiles.get_profile!(id)
    end

    test "create_profile/1 with valid attrs creates the profile" do
      ds = insert(:data_structure)
      attrs = Map.put(@valid_attrs, :data_structure_id, ds.id)

      assert {:ok, %Profile{value: value, data_structure_id: ds_id}} =
               Profiles.create_profile(attrs)

      assert ds.id == ds_id
      assert attrs.value == value
    end

    test "create_profile/1 with invalid attrs returns an error" do
      assert {:error, %Ecto.Changeset{}} = Profiles.create_profile(@invalid_attrs)
    end

    test "update_profile/1 with valid attrs updates the profile", %{profile: profile} do
      assert {:ok, %Profile{value: value}} = Profiles.update_profile(profile, @update_attrs)
      assert @update_attrs.value == value
    end
  end

  describe "TdDd.Profiles list" do
    test "list_profiles/1 without params lists all profiles" do
      profiles = Enum.map(1..8, fn _ -> insert(:profile) end)
      assert profiles ||| Profiles.list_profiles()
    end

    test "list_profiles/1 limit param" do
      first_5_profiles = Enum.map(1..5, fn _ -> insert(:profile) end)
      _another_5_profiles = Enum.map(1..5, fn _ -> insert(:profile) end)
      assert first_5_profiles ||| Profiles.list_profiles(%{"limit" => 5})
    end

    test "list_profiles/1 offset param" do
      _first_5_profiles = Enum.map(1..5, fn _ -> insert(:profile) end)
      another_5_profiles = Enum.map(1..5, fn _ -> insert(:profile) end)
      assert another_5_profiles ||| Profiles.list_profiles(%{"offset" => 5})
    end

    test "list_profiles/1 since filter param" do
      _first_5_profiles =
        Enum.map(1..5, fn day -> insert(:profile, updated_at: "2000-01-0#{day}T00:00:00") end)

      another_5_profiles =
        Enum.map(6..9, fn day -> insert(:profile, updated_at: "2000-01-0#{day}T00:00:00") end)

      assert another_5_profiles ||| Profiles.list_profiles(%{"since" => "2000-01-06T00:00:00"})
    end
  end

  describe "create_or_update_profile" do
    setup do
      d1 = insert(:data_structure)
      e1 = insert(:profile_execution, data_structure: d1)
      [data_structure: d1, execution: e1]
    end

    test "creates profile when it does not exist", %{
      data_structure: %{id: data_structure_id},
      execution: execution
    } do
      value = %{"foo" => "bar"}

      assert {:ok, %{id: id, data_structure_id: ^data_structure_id, value: ^value}} =
               Profiles.create_or_update_profile(%{
                 data_structure_id: data_structure_id,
                 value: value
               })

      assert %{
               profile_id: ^id,
               profile_events: [%{type: "SUCCEEDED", message: "Profile Uploaded."}]
             } = Executions.get_profile_execution(execution.id, preload: [:profile_events])
    end

    test "updates profile when it does not exist", %{
      data_structure: %{id: data_structure_id} = data_structure,
      execution: execution
    } do
      %{id: id} = insert(:profile, data_structure: data_structure, value: %{"bar" => "baz"})
      value = %{"foo" => "bar"}

      assert {:ok, %{id: ^id, data_structure_id: ^data_structure_id, value: ^value}} =
               Profiles.create_or_update_profile(%{
                 data_structure_id: data_structure_id,
                 value: value
               })

      assert %{
               profile_id: ^id,
               profile_events: [%{type: "SUCCEEDED", message: "Profile Uploaded."}]
             } = Executions.get_profile_execution(execution.id, preload: [:profile_events])
    end

    test "returns error when value is nil", %{
      data_structure: %{id: data_structure_id}
    } do
      assert {:error, %{errors: [value: {"can't be blank", [validation: :required]}]}} =
               Profiles.create_or_update_profile(%{
                 data_structure_id: data_structure_id,
                 value: nil
               })
    end

    test "returns error when data structure does not exist" do
      data_structure_id = System.unique_integer([:positive])

      assert {:error,
              %{
                errors: [
                  data_structure_id:
                    {"does not exist",
                     [constraint: :foreign, constraint_name: "profiles_data_structure_id_fkey"]}
                ]
              }} =
               Profiles.create_or_update_profile(%{
                 data_structure_id: data_structure_id,
                 value: %{"foo" => "bar"}
               })
    end
  end
end
