defmodule TdDq.Implementations.ImplementationTest do
  use TdDd.DataCase

  alias Ecto.Changeset
  alias TdDd.Repo
  alias TdDq.Implementations.Implementation

  setup do
    %{name: template_name} = CacheHelpers.insert_template(scope: "dq")
    [template_name: template_name]
  end

  describe "changeset/2" do
    test "validates existence of rule on insert" do
      params =
        :implementation
        |> string_params_for()
        |> Map.delete("rule")
        |> Map.put("rule_id", 123)

      assert %{valid?: true} = changeset = Implementation.changeset(params)
      assert {:error, changeset} = Repo.insert(changeset)
      assert %{errors: errors} = changeset
      assert {_msg, [constraint: :foreign, constraint_name: _constraint_name]} = errors[:rule_id]
    end

    test "puts next available implementation_key if none specified and changeset valid" do
      insert(:implementation, implementation_key: "ri0123")
      %{id: rule_id} = insert(:rule)

      params =
        :implementation
        |> string_params_for(rule_id: rule_id)
        |> Map.delete("implementation_key")

      assert %{changes: changes, valid?: true} = Implementation.changeset(params)
      assert %{implementation_key: "ri0124"} = changes
    end

    test "does not automatically put implementation_key if one is specified" do
      params = %{implementation_key: "foo"}

      assert %{changes: changes} = Implementation.changeset(params)
      assert %{implementation_key: "foo"} = changes
    end

    test "does not automatically put implementation_key if changeset is invalid" do
      params = %{}

      assert %{changes: changes, valid?: false} = Implementation.changeset(params)
      refute Map.has_key?(changes, :implementation_key)
    end

    test "validates df_content is required if df_name is present", %{template_name: template_name} do
      params = params_for(:implementation, df_name: template_name, df_content: nil)
      assert %{valid?: false, errors: errors} = Implementation.changeset(params)
      assert errors[:df_content] == {"can't be blank", [validation: :required]}
    end

    test "validates df_content is valid", %{template_name: template_name} do
      invalid_content = %{"list" => "foo", "string" => "whatever"}
      params = params_for(:implementation, df_name: template_name, df_content: invalid_content)
      assert %{valid?: false, errors: errors} = Implementation.changeset(params)
      assert {"invalid content", _detail} = errors[:df_content]
    end

    test "executable default true field" do
      %{id: rule_id} = insert(:rule)
      params = string_params_for(:implementation, rule_id: rule_id, implementation_key: "foo")
      assert %{valid?: true} = changeset = Implementation.changeset(params)
      assert Changeset.get_field(changeset, :executable)
    end

    test "validates result_type value" do
      rule = insert(:rule)
      params = params_for(:implementation, result_type: "foo", rule: rule)
      assert %{valid?: false, errors: errors} = Implementation.changeset(params)
      assert {_, [validation: :inclusion, enum: _valid_values]} = errors[:result_type]
    end

    test "validates goal and minimum are between 0 and 100 if result_type is percentage" do
      rule = insert(:rule)

      params =
        params_for(:implementation, result_type: "percentage", goal: 101, minimum: -1, rule: rule)

      assert %{valid?: false, errors: errors} = Implementation.changeset(params)
      assert {_, [validation: :number, kind: :less_than_or_equal_to, number: 100]} = errors[:goal]

      assert {_, [validation: :number, kind: :greater_than_or_equal_to, number: 0]} =
               errors[:minimum]
    end

    test "validates goal and minimum are between 0 and 100 if result_type is deviation" do
      rule = insert(:rule)

      params =
        params_for(:implementation, result_type: "deviation", goal: -1, minimum: 101, rule: rule)

      assert %{valid?: false, errors: errors} = Implementation.changeset(params)

      assert {_, [validation: :number, kind: :less_than_or_equal_to, number: 100]} =
               errors[:minimum]

      assert {_, [validation: :number, kind: :greater_than_or_equal_to, number: 0]} =
               errors[:goal]
    end

    test "validates goal and minimum >= 0 if result_type is errors_number" do
      rule = insert(:rule)

      params =
        params_for(:implementation,
          result_type: "errors_number",
          goal: -1,
          minimum: -1,
          rule: rule
        )

      assert %{valid?: false, errors: errors} = Implementation.changeset(params)

      assert {_, [validation: :number, kind: :greater_than_or_equal_to, number: 0]} =
               errors[:goal]

      assert {_, [validation: :number, kind: :greater_than_or_equal_to, number: 0]} =
               errors[:minimum]
    end

    test "validates goal >= minimum if result_type is percentage" do
      rule = insert(:rule)

      params =
        params_for(:implementation, result_type: "percentage", goal: 30, minimum: 40, rule: rule)

      assert %{valid?: false, errors: errors} = Implementation.changeset(params)
      assert errors[:goal] == {"must.be.greater.than.or.equal.to.minimum", []}
    end

    test "validates minimum >= goal if result_type is deviation" do
      rule = insert(:rule)

      params =
        params_for(:implementation, result_type: "deviation", goal: 80, minimum: 70, rule: rule)

      assert %{valid?: false, errors: errors} = Implementation.changeset(params)
      assert errors[:minimum] == {"must.be.greater.than.or.equal.to.goal", []}
    end

    test "validates minimum >= goal if result_type is errors_numer" do
      rule = insert(:rule)

      params =
        params_for(:implementation,
          result_type: "errors_number",
          goal: 400,
          minimum: 30,
          rule: rule
        )

      assert %{valid?: false, errors: errors} = Implementation.changeset(params)
      assert errors[:minimum] == {"must.be.greater.than.or.equal.to.goal", []}
    end
  end
end
