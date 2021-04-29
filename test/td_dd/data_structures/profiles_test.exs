defmodule TdDd.DataStructures.ProfilesTest do
  use TdDd.DataStructureCase

  alias TdDd.DataStructures.Profile
  alias TdDd.DataStructures.Profiles
  alias TdDd.Executions

  describe "TdDd.DataStructures.Profiles" do
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
  end
end
