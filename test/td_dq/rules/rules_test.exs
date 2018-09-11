defmodule TdDq.RulesTest do
  use TdDq.DataCase
  import TdDq.Factory

  alias TdDq.Rules

  describe "rule_implementations" do
    alias TdDq.Rules.RuleImplementation

    test "list_rule_implementations/0 returns all rule_implementations" do
      rule_implementation = insert(:rule_implementation)

      assert Enum.map(Rules.list_rule_implementations(), &rule_implementation_preload(&1)) == [
               rule_implementation
             ]
    end

    test "get_rule_implementation!/1 returns the rule_implementation with given id" do
      rule_implementation = insert(:rule_implementation)
      assert rule_implementation_preload(Rules.get_rule_implementation!(rule_implementation.id)) == rule_implementation
    end

    test "create_rule_implementation/1 with valid data creates a rule_implementation" do
      rule = insert(:rule)

      creation_attrs =
        Map.from_struct(
          build(
            :rule_implementation,
            rule_id: rule.id
          )
        )

      assert {:ok, %RuleImplementation{} = rule_implementation} =
               Rules.create_rule_implementation(creation_attrs)

      assert rule_implementation.rule_id == creation_attrs[:rule_id]
      assert rule_implementation.description == creation_attrs[:description]
      assert rule_implementation.system_params == creation_attrs[:system_params]
      assert rule_implementation.system == creation_attrs[:system]
      assert rule_implementation.tag == creation_attrs[:tag]
    end

    test "create_rule_implementation/1 with invalid data returns error changeset" do
      rule = insert(:rule)

      creation_attrs =
        Map.from_struct(
          build(:rule_implementation, rule_id: rule.id, name: nil, system: nil)
        )

      assert {:error, %Ecto.Changeset{}} = Rules.create_rule_implementation(creation_attrs)
    end

    test "update_rule_implementation/2 with valid data updates the rule_implementation" do
      rule_implementation = insert(:rule_implementation)
      update_attrs = Map.from_struct(rule_implementation)

      update_attrs =
        update_attrs
        |> Map.put(:name, "New name")
        |> Map.put(:system, "New system")
        |> Map.put(:description, "New description")

      assert {:ok, rule_implementation} = Rules.update_rule_implementation(rule_implementation, update_attrs)
      assert %RuleImplementation{} = rule_implementation
      assert rule_implementation.rule_id == update_attrs[:rule_id]
      assert rule_implementation.description == update_attrs[:description]
      assert rule_implementation.system_params == update_attrs[:system_params]
      assert rule_implementation.system == update_attrs[:system]
      assert rule_implementation.tag == update_attrs[:tag]
    end

    test "update_rule_implementation/2 with invalid data returns error changeset" do
      rule_implementation = insert(:rule_implementation)
      update_attrs = Map.from_struct(rule_implementation)

      udpate_attrs =
        update_attrs
        |> Map.put(:name, nil)
        |> Map.put(:system, nil)

      assert {:error, %Ecto.Changeset{}} =
               Rules.update_rule_implementation(rule_implementation, udpate_attrs)

      assert rule_implementation == rule_implementation_preload(Rules.get_rule_implementation!(rule_implementation.id))
    end

    test "delete_rule_implementation/1 deletes the rule_implementation" do
      rule_implementation = insert(:rule_implementation)
      assert {:ok, %RuleImplementation{}} = Rules.delete_rule_implementation(rule_implementation)
      assert_raise Ecto.NoResultsError, fn -> Rules.get_rule_implementation!(rule_implementation.id) end
    end

    test "change_rule_implementation/1 returns a rule_implementation changeset" do
      rule_implementation = insert(:rule_implementation)
      assert %Ecto.Changeset{} = Rules.change_rule_implementation(rule_implementation)
    end

    defp rule_implementation_preload(rule_implementation) do
      rule_implementation
      |> Repo.preload([:rule, rule: :rule_type])
    end
  end

  describe "rule_type" do
    alias TdDq.Rules.RuleType

    @valid_attrs %{name: "some name", params: %{}}
    @update_attrs %{name: "some updated name", params: %{}}
    @invalid_attrs %{name: nil, params: nil}

    def rule_type_fixture(attrs \\ %{}) do
      {:ok, rule_type} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Rules.create_rule_type()

      rule_type
    end

    test "list_rule_types/0 returns all rule_type" do
      rule_type = rule_type_fixture()
      assert Enum.member?(Rules.list_rule_types(), rule_type)
    end

    test "get_rule_type!/1 returns the rule_type with given id" do
      rule_type = rule_type_fixture()
      assert Rules.get_rule_type!(rule_type.id) == rule_type
    end

    test "create_rule_type/1 with valid data creates a rule_type" do
      assert {:ok, %RuleType{} = rule_type} =
               Rules.create_rule_type(@valid_attrs)

      assert rule_type.name == "some name"
      assert rule_type.params == %{}
    end

    test "create_rule_type/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Rules.create_rule_type(@invalid_attrs)
    end

    test "update_rule_type/2 with valid data updates the rule_type" do
      rule_type = rule_type_fixture()

      assert {:ok, rule_type} =
               Rules.update_rule_type(rule_type, @update_attrs)

      assert %RuleType{} = rule_type
      assert rule_type.name == "some updated name"
      assert rule_type.params == %{}
    end

    test "update_rule_type/2 with invalid data returns error changeset" do
      rule_type = rule_type_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Rules.update_rule_type(rule_type, @invalid_attrs)

      assert rule_type == Rules.get_rule_type!(rule_type.id)
    end

    test "delete_rule_type/1 deletes the rule_type" do
      rule_type = rule_type_fixture()
      assert {:ok, %RuleType{}} = Rules.delete_rule_type(rule_type)

      assert_raise Ecto.NoResultsError, fn ->
        Rules.get_rule_type!(rule_type.id)
      end
    end

    test "change_rule_type/1 returns a rule_type changeset" do
      rule_type = rule_type_fixture()
      assert %Ecto.Changeset{} = Rules.change_rule_type(rule_type)
    end

    test "create_duplicated_rule_type/1 with valid data creates a rule_type" do
      assert {:ok, %RuleType{} = rule_type} =
               Rules.create_rule_type(@valid_attrs)

      assert rule_type.name == "some name"
      assert rule_type.params == %{}

      assert {:error, %Ecto.Changeset{} = changeset} =
               Rules.create_rule_type(@valid_attrs)

      assert changeset.valid? == false
      assert changeset.errors == [name: {"has already been taken", []}]
    end
  end

  describe "rule_result" do

    defp add_to_date_time(datetime, increment) do
      DateTime.from_unix!(DateTime.to_unix(datetime) + increment)
    end

    test "get_last_rule_result/1 returns last rule_implementation rule result" do
      rule_implementation = insert(:rule_implementation)
      now = DateTime.utc_now()
      insert(:rule_result, rule_implementation: rule_implementation, result: 10, date: add_to_date_time(now, -1000))
      rule_result = insert(:rule_result, rule_implementation: rule_implementation, result: 60, date: now)
      insert(:rule_result, rule_implementation: rule_implementation, result: 80, date: add_to_date_time(now, -2000))

      assert rule_result.result == Rules.get_last_rule_result(rule_implementation.id).result
    end

  end
end
