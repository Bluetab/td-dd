defmodule TdDd.DataStructures.ProfilesTest do
  use TdDd.DataStructureCase

  alias TdDd.DataStructures.Profile
  alias TdDd.DataStructures.Profiles

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
end
