defmodule TdDq.Implementations.ImplementationTest do
  use TdDd.DataCase

  alias Ecto.Changeset
  alias Elasticsearch.Document
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
      params = params_for(:rule, df_name: template_name, df_content: invalid_content)
      assert %{valid?: false, errors: errors} = Implementation.changeset(params)
      assert {"invalid content", _detail} = errors[:df_content]
    end

    test "executable default true field" do
      %{id: rule_id} = insert(:rule)
      params = string_params_for(:implementation, rule_id: rule_id, implementation_key: "foo")
      assert %{valid?: true} = changeset = Implementation.changeset(params)
      assert Changeset.get_field(changeset, :executable)
    end
  end

  describe "encode" do
    test "encoded implementation includes validation modifier" do
      rule = insert(:rule)

      creation_attrs = %{
        validations: [
          %{
            operator: %{
              name: "timestamp_gt_timestamp",
              value_type: "timestamp",
              value_type_filter: "timestamp"
            },
            structure: %{id: 7, name: "s7"},
            value: [%{raw: "2019-12-02 05:35:00"}],
            modifier: build(:modifier),
            value_modifier: [build(:modifier)]
          }
        ]
      }

      implementation_key = "rik1"

      rule_implementation =
        insert(:implementation,
          implementation_key: implementation_key,
          rule: rule,
          validations: creation_attrs.validations
        )

      assert %{
               validations: [
                 %{
                   value_modifier: [
                     %{
                       name: _,
                       params: %{}
                     }
                   ],
                   modifier: %{
                     name: _,
                     params: %{}
                   }
                 }
               ]
             } = Document.encode(rule_implementation)
    end
  end
end
