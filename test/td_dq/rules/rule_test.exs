defmodule TdDq.Rules.RuleTest do
  use TdDd.DataCase

  alias TdDd.Repo
  alias TdDq.Rules.Rule

  setup do
    %{name: template_name} = CacheHelpers.insert_template(scope: "dq")
    domain = CacheHelpers.insert_domain()

    [domain: domain, template_name: template_name]
  end

  describe "changeset/2" do
    test "validates required fields" do
      rule = insert(:rule)

      Enum.each([:name, :domain_id], fn field ->
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

    test "validates df_content is required if df_name is present", %{
      template_name: template_name,
      domain: domain
    } do
      params = params_for(:rule, df_name: template_name, df_content: nil, domain_id: domain.id)
      assert %{valid?: false, errors: errors} = Rule.changeset(params)
      assert errors[:df_content] == {"can't be blank", [validation: :required]}
    end

    test "validates df_content is valid", %{template_name: template_name, domain: domain} do
      invalid_content = %{"list" => "foo", "string" => "whatever"}

      params =
        params_for(:rule,
          df_name: template_name,
          df_content: invalid_content,
          domain_id: domain.id
        )

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
