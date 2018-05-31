defmodule TdDq.QualityRulesTest do
  use TdDq.DataCase
  import TdDq.Factory

  alias TdDq.QualityRules

  describe "quality_rules" do
    alias TdDq.QualityRules.QualityRule

    test "list_quality_rules/0 returns all quality_rules" do
      quality_rule = insert(:quality_rule)
      assert Enum.map(QualityRules.list_quality_rules(), &quality_rule_preload(&1)) == [quality_rule]
    end

    test "get_quality_rule!/1 returns the quality_rule with given id" do
      quality_rule = insert(:quality_rule)
      assert quality_rule_preload(QualityRules.get_quality_rule!(quality_rule.id)) == quality_rule
    end

    test "create_quality_rule/1 with valid data creates a quality_rule" do
      quality_control = insert(:quality_control)
      quality_rule_type = insert(:quality_rule_type)
      creation_attrs = Map.from_struct(build(:quality_rule, quality_control_id: quality_control.id, quality_rule_type_id: quality_rule_type.id))
      assert {:ok, %QualityRule{} = quality_rule} = QualityRules.create_quality_rule(creation_attrs)
      assert quality_rule.quality_control_id == creation_attrs[:quality_control_id]
      assert quality_rule.description == creation_attrs[:description]
      assert quality_rule.type_params == creation_attrs[:type_params]
      assert quality_rule.system == creation_attrs[:system]
      assert quality_rule.type == creation_attrs[:type]
      assert quality_rule.tag == creation_attrs[:tag]
    end

    test "create_quality_rule/1 with invalid data returns error changeset" do
      quality_control = insert(:quality_control)
      creation_attrs = Map.from_struct(build(:quality_rule, quality_control_id: quality_control.id, name: nil, system: nil))
      assert {:error, %Ecto.Changeset{}} = QualityRules.create_quality_rule(creation_attrs)
    end

    test "update_quality_rule/2 with valid data updates the quality_rule" do
      quality_rule = insert(:quality_rule)
      update_attrs = Map.from_struct(quality_rule)
      update_attrs = update_attrs
      |> Map.put(:name, "New name")
      |> Map.put(:system, "New system")
      |> Map.put(:description, "New description")

      assert {:ok, quality_rule} = QualityRules.update_quality_rule(quality_rule, update_attrs)
      assert %QualityRule{} = quality_rule
      assert quality_rule.quality_control_id == update_attrs[:quality_control_id]
      assert quality_rule.description == update_attrs[:description]
      assert quality_rule.type_params == update_attrs[:type_params]
      assert quality_rule.system == update_attrs[:system]
      assert quality_rule.type == update_attrs[:type]
      assert quality_rule.tag == update_attrs[:tag]
    end

    test "update_quality_rule/2 with invalid data returns error changeset" do
      quality_rule = insert(:quality_rule)
      update_attrs = Map.from_struct(quality_rule)
      udpate_attrs = update_attrs
      |> Map.put(:name, nil)
      |> Map.put(:system, nil)
      assert {:error, %Ecto.Changeset{}} = QualityRules.update_quality_rule(quality_rule, udpate_attrs)
      assert quality_rule == quality_rule_preload(QualityRules.get_quality_rule!(quality_rule.id))
    end

    test "delete_quality_rule/1 deletes the quality_rule" do
      quality_rule = insert(:quality_rule)
      assert {:ok, %QualityRule{}} = QualityRules.delete_quality_rule(quality_rule)
      assert_raise Ecto.NoResultsError, fn -> QualityRules.get_quality_rule!(quality_rule.id) end
    end

    test "change_quality_rule/1 returns a quality_rule changeset" do
      quality_rule = insert(:quality_rule)
      assert %Ecto.Changeset{} = QualityRules.change_quality_rule(quality_rule)
    end

    defp quality_rule_preload(quality_rule) do
      quality_rule
      |> Repo.preload(:quality_control)
      |> Repo.preload(:quality_rule_type)
    end
  end

  describe "quality_rule_type" do
    alias TdDq.QualityRules.QualityRuleType

    @valid_attrs %{name: "some name", params: %{}}
    @update_attrs %{name: "some updated name", params: %{}}
    @invalid_attrs %{name: nil, params: nil}

    def quality_rule_type_fixture(attrs \\ %{}) do
      {:ok, quality_rule_type} =
        attrs
        |> Enum.into(@valid_attrs)
        |> QualityRules.create_quality_rule_type()

      quality_rule_type
    end

    test "list_quality_rule_types/0 returns all quality_rule_type" do
      quality_rule_type = quality_rule_type_fixture()
      assert QualityRules.list_quality_rule_types() == [quality_rule_type]
    end

    test "get_quality_rule_type!/1 returns the quality_rule_type with given id" do
      quality_rule_type = quality_rule_type_fixture()
      assert QualityRules.get_quality_rule_type!(quality_rule_type.id) == quality_rule_type
    end

    test "create_quality_rule_type/1 with valid data creates a quality_rule_type" do
      assert {:ok, %QualityRuleType{} = quality_rule_type} = QualityRules.create_quality_rule_type(@valid_attrs)
      assert quality_rule_type.name == "some name"
      assert quality_rule_type.params == %{}
    end

    test "create_quality_rule_type/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = QualityRules.create_quality_rule_type(@invalid_attrs)
    end

    test "update_quality_rule_type/2 with valid data updates the quality_rule_type" do
      quality_rule_type = quality_rule_type_fixture()
      assert {:ok, quality_rule_type} = QualityRules.update_quality_rule_type(quality_rule_type, @update_attrs)
      assert %QualityRuleType{} = quality_rule_type
      assert quality_rule_type.name == "some updated name"
      assert quality_rule_type.params == %{}
    end

    test "update_quality_rule_type/2 with invalid data returns error changeset" do
      quality_rule_type = quality_rule_type_fixture()
      assert {:error, %Ecto.Changeset{}} = QualityRules.update_quality_rule_type(quality_rule_type, @invalid_attrs)
      assert quality_rule_type == QualityRules.get_quality_rule_type!(quality_rule_type.id)
    end

    test "delete_quality_rule_type/1 deletes the quality_rule_type" do
      quality_rule_type = quality_rule_type_fixture()
      assert {:ok, %QualityRuleType{}} = QualityRules.delete_quality_rule_type(quality_rule_type)
      assert_raise Ecto.NoResultsError, fn -> QualityRules.get_quality_rule_type!(quality_rule_type.id) end
    end

    test "change_quality_rule_type/1 returns a quality_rule_type changeset" do
      quality_rule_type = quality_rule_type_fixture()
      assert %Ecto.Changeset{} = QualityRules.change_quality_rule_type(quality_rule_type)
    end

    test "create_duplicated_quality_rule_type/1 with valid data creates a quality_rule_type" do
      assert {:ok, %QualityRuleType{} = quality_rule_type} = QualityRules.create_quality_rule_type(@valid_attrs)
      assert quality_rule_type.name == "some name"
      assert quality_rule_type.params == %{}
      assert {:error, %Ecto.Changeset{} = changeset} = QualityRules.create_quality_rule_type(@valid_attrs)
      assert changeset.valid? == false
      assert changeset.errors == [name: {"has already been taken", []}]
    end
  end
end
