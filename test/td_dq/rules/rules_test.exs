defmodule TdDq.RulesTest do
  use TdDq.DataCase
  import TdDq.Factory

  alias TdDq.Rules

  describe "quality_rules" do
    alias TdDq.Rules.RuleImplementation

    test "list_rule_implementations/0 returns all quality_rules" do
      quality_rule = insert(:rule_implementation)

      assert Enum.map(Rules.list_rule_implementations(), &quality_rule_preload(&1)) == [
               quality_rule
             ]
    end

    test "get_rule_implementation!/1 returns the quality_rule with given id" do
      quality_rule = insert(:rule_implementation)
      assert quality_rule_preload(Rules.get_rule_implementation!(quality_rule.id)) == quality_rule
    end

    test "create_rule_implementation/1 with valid data creates a quality_rule" do
      quality_control = insert(:rule)
      quality_rule_type = insert(:rule_type)

      creation_attrs =
        Map.from_struct(
          build(
            :rule_implementation,
            rule_id: quality_control.id,
            rule_type_id: quality_rule_type.id
          )
        )

      assert {:ok, %RuleImplementation{} = quality_rule} =
               Rules.create_rule_implementation(creation_attrs)

      assert quality_rule.rule_id == creation_attrs[:rule_id]
      assert quality_rule.description == creation_attrs[:description]
      assert quality_rule.system_params == creation_attrs[:system_params]
      assert quality_rule.system == creation_attrs[:system]
      assert quality_rule.type == creation_attrs[:type]
      assert quality_rule.tag == creation_attrs[:tag]
    end

    test "create_rule_implementation/1 with invalid data returns error changeset" do
      quality_control = insert(:rule)

      creation_attrs =
        Map.from_struct(
          build(:rule_implementation, rule_id: quality_control.id, name: nil, system: nil)
        )

      assert {:error, %Ecto.Changeset{}} = Rules.create_rule_implementation(creation_attrs)
    end

    test "update_rule_implementation/2 with valid data updates the quality_rule" do
      quality_rule = insert(:rule_implementation)
      update_attrs = Map.from_struct(quality_rule)

      update_attrs =
        update_attrs
        |> Map.put(:name, "New name")
        |> Map.put(:system, "New system")
        |> Map.put(:description, "New description")

      assert {:ok, quality_rule} = Rules.update_rule_implementation(quality_rule, update_attrs)
      assert %RuleImplementation{} = quality_rule
      assert quality_rule.rule_id == update_attrs[:rule_id]
      assert quality_rule.description == update_attrs[:description]
      assert quality_rule.system_params == update_attrs[:system_params]
      assert quality_rule.system == update_attrs[:system]
      assert quality_rule.type == update_attrs[:type]
      assert quality_rule.tag == update_attrs[:tag]
    end

    test "update_rule_implementation/2 with invalid data returns error changeset" do
      quality_rule = insert(:rule_implementation)
      update_attrs = Map.from_struct(quality_rule)

      udpate_attrs =
        update_attrs
        |> Map.put(:name, nil)
        |> Map.put(:system, nil)

      assert {:error, %Ecto.Changeset{}} =
               Rules.update_rule_implementation(quality_rule, udpate_attrs)

      assert quality_rule == quality_rule_preload(Rules.get_rule_implementation!(quality_rule.id))
    end

    test "delete_rule_implementation/1 deletes the quality_rule" do
      quality_rule = insert(:rule_implementation)
      assert {:ok, %RuleImplementation{}} = Rules.delete_rule_implementation(quality_rule)
      assert_raise Ecto.NoResultsError, fn -> Rules.get_rule_implementation!(quality_rule.id) end
    end

    test "change_rule_implementation/1 returns a quality_rule changeset" do
      quality_rule = insert(:rule_implementation)
      assert %Ecto.Changeset{} = Rules.change_rule_implementation(quality_rule)
    end

    defp quality_rule_preload(quality_rule) do
      quality_rule
      |> Repo.preload(:rule)
      |> Repo.preload(:rule_type)
    end
  end

  describe "quality_rule_type" do
    alias TdDq.Rules.RuleType

    @valid_attrs %{name: "some name", params: %{}}
    @update_attrs %{name: "some updated name", params: %{}}
    @invalid_attrs %{name: nil, params: nil}

    def quality_rule_type_fixture(attrs \\ %{}) do
      {:ok, quality_rule_type} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Rules.create_rule_type()

      quality_rule_type
    end

    test "list_rule_types/0 returns all quality_rule_type" do
      quality_rule_type = quality_rule_type_fixture()
      assert Enum.member?(Rules.list_rule_types(), quality_rule_type)
    end

    test "get_rule_type!/1 returns the quality_rule_type with given id" do
      quality_rule_type = quality_rule_type_fixture()
      assert Rules.get_rule_type!(quality_rule_type.id) == quality_rule_type
    end

    test "create_rule_type/1 with valid data creates a quality_rule_type" do
      assert {:ok, %RuleType{} = quality_rule_type} =
               Rules.create_rule_type(@valid_attrs)

      assert quality_rule_type.name == "some name"
      assert quality_rule_type.params == %{}
    end

    test "create_rule_type/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Rules.create_rule_type(@invalid_attrs)
    end

    test "update_rule_type/2 with valid data updates the quality_rule_type" do
      quality_rule_type = quality_rule_type_fixture()

      assert {:ok, quality_rule_type} =
               Rules.update_rule_type(quality_rule_type, @update_attrs)

      assert %RuleType{} = quality_rule_type
      assert quality_rule_type.name == "some updated name"
      assert quality_rule_type.params == %{}
    end

    test "update_rule_type/2 with invalid data returns error changeset" do
      quality_rule_type = quality_rule_type_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Rules.update_rule_type(quality_rule_type, @invalid_attrs)

      assert quality_rule_type == Rules.get_rule_type!(quality_rule_type.id)
    end

    test "delete_rule_type/1 deletes the quality_rule_type" do
      quality_rule_type = quality_rule_type_fixture()
      assert {:ok, %RuleType{}} = Rules.delete_rule_type(quality_rule_type)

      assert_raise Ecto.NoResultsError, fn ->
        Rules.get_rule_type!(quality_rule_type.id)
      end
    end

    test "change_rule_type/1 returns a quality_rule_type changeset" do
      quality_rule_type = quality_rule_type_fixture()
      assert %Ecto.Changeset{} = Rules.change_rule_type(quality_rule_type)
    end

    test "create_duplicated_quality_rule_type/1 with valid data creates a quality_rule_type" do
      assert {:ok, %RuleType{} = quality_rule_type} =
               Rules.create_rule_type(@valid_attrs)

      assert quality_rule_type.name == "some name"
      assert quality_rule_type.params == %{}

      assert {:error, %Ecto.Changeset{} = changeset} =
               Rules.create_rule_type(@valid_attrs)

      assert changeset.valid? == false
      assert changeset.errors == [name: {"has already been taken", []}]
    end
  end
end
