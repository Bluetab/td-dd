defmodule TdDq.Rules.RuleTest do
  use TdDd.DataCase

  alias TdCache.TemplateCache
  alias TdDd.Repo
  alias TdDq.Rules.Rule

  setup_all do
    %{id: template_id, name: template_name} = template = build(:template)
    domain = CacheHelpers.insert_domain()
    {:ok, _} = TemplateCache.put(template)
    on_exit(fn -> TemplateCache.delete(template_id) end)

    [domain: domain, template_name: template_name]
  end

  describe "changeset/1" do
    test "validates required fields" do
      rule = insert(:rule)

      Enum.each([:name, :goal, :minimum, :result_type, :domain_id], fn field ->
        assert %{valid?: false, errors: errors} = Rule.changeset(rule, %{field => nil})
        assert {_message, [validation: :required]} = errors[field]
      end)
    end

    test "validates unique constraint on name and business_concept_id", %{domain: domain} do
      %{name: name} = insert(:rule, business_concept_id: "123")

      assert {:error, changeset} =
               :rule
               |> params_for(name: name, business_concept_id: "123", domain_id: domain.id)
               |> Rule.changeset()
               |> Repo.insert()

      assert %{valid?: false, errors: errors} = changeset

      assert errors[:rule_name_bc_id] ==
               {"unique_constraint",
                [constraint: :unique, constraint_name: "rules_business_concept_id_name_index"]}
    end

    test "validates unique constraint on name when business_concept_id is nil", %{domain: domain} do
      %{name: name} = insert(:rule, business_concept_id: nil)

      assert {:error, changeset} =
               :rule
               |> params_for(name: name, business_concept_id: nil, domain_id: domain.id)
               |> Rule.changeset()
               |> Repo.insert()

      assert %{valid?: false, errors: errors} = changeset

      assert errors[:rule_name_bc_id] ==
               {"unique_constraint", [constraint: :unique, constraint_name: "rules_name_index"]}
    end

    test "validates result_type value", %{domain: domain} do
      params = params_for(:rule, result_type: "foo", domain_id: domain.id)
      assert %{valid?: false, errors: errors} = Rule.changeset(params)
      assert {_, [validation: :inclusion, enum: _valid_values]} = errors[:result_type]
    end

    test "validates goal and minimum are between 0 and 100 if result_type is percentage", %{domain: domain} do
      params = params_for(:rule, result_type: "percentage", goal: 101, minimum: -1, domain_id: domain.id)
      assert %{valid?: false, errors: errors} = Rule.changeset(params)
      assert {_, [validation: :number, kind: :less_than_or_equal_to, number: 100]} = errors[:goal]

      assert {_, [validation: :number, kind: :greater_than_or_equal_to, number: 0]} =
               errors[:minimum]
    end

    test "validates goal and minimum are between 0 and 100 if result_type is deviation", %{domain: domain} do
      params = params_for(:rule, result_type: "deviation", goal: -1, minimum: 101, domain_id: domain.id)
      assert %{valid?: false, errors: errors} = Rule.changeset(params)
      assert {_, [validation: :number, kind: :less_than_or_equal_to, number: 100]} = errors[:minimum]

      assert {_, [validation: :number, kind: :greater_than_or_equal_to, number: 0]} =
               errors[:goal]
    end

    test "validates goal and minimum >= 0 if result_type is errors_number", %{domain: domain} do
      params = params_for(:rule, result_type: "errors_number", goal: -1, minimum: -1, domain_id: domain.id)
      assert %{valid?: false, errors: errors} = Rule.changeset(params)

      assert {_, [validation: :number, kind: :greater_than_or_equal_to, number: 0]} =
               errors[:goal]

      assert {_, [validation: :number, kind: :greater_than_or_equal_to, number: 0]} =
               errors[:minimum]
    end

    test "validates goal >= minimum if result_type is percentage", %{domain: domain} do
      params = params_for(:rule, result_type: "percentage", goal: 30, minimum: 40, domain_id: domain.id)
      assert %{valid?: false, errors: errors} = Rule.changeset(params)
      assert errors[:goal] == {"must.be.greater.than.or.equal.to.minimum", []}
    end

    test "validates minimum >= goal if result_type is deviation", %{domain: domain} do
      params = params_for(:rule, result_type: "deviation", goal: 80, minimum: 70, domain_id: domain.id)
      assert %{valid?: false, errors: errors} = Rule.changeset(params)
      assert errors[:minimum] == {"must.be.greater.than.or.equal.to.goal", []}
    end

    test "validates minimum >= goal if result_type is errors_numer", %{domain: domain} do
      params = params_for(:rule, result_type: "errors_number", goal: 400, minimum: 30, domain_id: domain.id)
      assert %{valid?: false, errors: errors} = Rule.changeset(params)
      assert errors[:minimum] == {"must.be.greater.than.or.equal.to.goal", []}
    end

    test "validates df_content is required if df_name is present", %{template_name: template_name, domain: domain} do
      params = params_for(:rule, df_name: template_name, df_content: nil, domain_id: domain.id)
      assert %{valid?: false, errors: errors} = Rule.changeset(params)
      assert errors[:df_content] == {"can't be blank", [validation: :required]}
    end

    test "validates df_content is valid", %{template_name: template_name, domain: domain} do
      invalid_content = %{"list" => "foo", "string" => "whatever"}
      params = params_for(:rule, df_name: template_name, df_content: invalid_content, domain_id: domain.id)
      assert %{valid?: false, errors: errors} = Rule.changeset(params)
      assert {"invalid content", _detail} = errors[:df_content]
    end
  end

  describe "delete_changeset/1" do
    test "validates a rule has no implementations" do
      %{rule: rule} = insert(:implementation)

      assert {:error, changeset} =
               rule
               |> Rule.delete_changeset()
               |> Repo.delete()

      assert %{valid?: false, errors: errors} = changeset
      assert {_, [constraint: :no_assoc, constraint_name: _]} = errors[:rule_implementations]
    end
  end
end
