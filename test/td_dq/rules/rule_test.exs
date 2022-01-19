defmodule TdDq.Rules.RuleTest do
  use TdDd.DataCase

  alias Ecto.Changeset
  alias TdDd.Repo
  alias TdDq.Rules.Rule

  setup do
    identifier_name = "identifier"

    with_identifier = %{
      id: System.unique_integer([:positive]),
      name: "rule_with_identifier",
      label: "rule_with_identifier",
      scope: "dq",
      content: [
        %{
          "fields" => [
            %{
              "cardinality" => "1",
              "default" => "",
              "label" => "Identifier",
              "name" => identifier_name,
              "subscribable" => false,
              "type" => "string",
              "values" => nil,
              "widget" => "identifier"
            },
            %{
              "cardinality" => "1",
              "default" => "",
              "label" => "Text",
              "name" => "text",
              "subscribable" => false,
              "type" => "string",
              "values" => nil,
              "widget" => "text"
            }
          ],
          "name" => ""
        }
      ]
    }

    template_with_identifier = CacheHelpers.insert_template(with_identifier)

    %{name: template_name} = CacheHelpers.insert_template(scope: "dq")
    domain = CacheHelpers.insert_domain()

    [
      domain: domain,
      template_name: template_name,
      template_with_identifier: template_with_identifier,
      identifier_name: identifier_name
    ]
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

    test "create new rule: puts a new identifier if the template has an identifier field", %{
      template_with_identifier: template_with_identifier,
      identifier_name: identifier_name,
      domain: domain
    } do
      params =
        params_for(:rule,
          df_name: template_with_identifier.name,
          df_content: %{"text" => "patata"},
          domain_id: domain.id
        )

      assert %Changeset{changes: changes} = Rule.changeset(params)

      assert %{df_content: new_content} = changes
      assert %{^identifier_name => _identifier} = new_content
    end

    test "create new rule: avoids putting new identifier if template lacks an identifier field",
         %{
           template_name: template_name,
           identifier_name: identifier_name,
           domain: domain
         } do
      params =
        params_for(:rule,
          df_name: template_name,
          df_content: %{"text" => "patata"},
          domain_id: domain.id
        )

      assert %Changeset{changes: changes} = Rule.changeset(params)

      assert %{df_content: new_content} = changes
      refute match?(%{^identifier_name => _identifier}, new_content)
    end

    test "keeps an already present identifier (i.e., editing)", %{
      template_with_identifier: template_with_identifier,
      identifier_name: identifier_name,
      domain: domain
    } do
      # Existing identifier previously put by the create changeset
      existing_identifier = "00000000-0000-0000-0000-000000000000"

      rule =
        insert(:rule,
          business_concept_id: "123",
          df_content: %{identifier_name => existing_identifier}
        )

      params =
        params_for(:rule,
          df_name: template_with_identifier.name,
          df_content: %{"text" => "patata"},
          domain_id: domain.id
        )

      assert %Changeset{changes: changes} = Rule.changeset(rule, params)

      assert %{df_content: new_content} = changes
      assert %{^identifier_name => ^existing_identifier} = new_content
    end

    test "keeps an already present identifier (i.e., editing) if extraneous identifier attr is passed",
         %{
           template_with_identifier: template_with_identifier,
           identifier_name: identifier_name,
           domain: domain
         } do
      # Existing identifier previously put by the create changeset
      existing_identifier = "00000000-0000-0000-0000-000000000000"

      rule =
        insert(:rule,
          business_concept_id: "123",
          df_content: %{identifier_name => existing_identifier}
        )

      params =
        params_for(:rule,
          df_name: template_with_identifier.name,
          df_content: %{
            "text" => "patata",
            identifier_name => "11111111-1111-1111-1111-111111111111"
          },
          domain_id: domain.id
        )

      assert %Changeset{changes: changes} = Rule.changeset(rule, params)

      assert %{df_content: new_content} = changes
      assert %{^identifier_name => ^existing_identifier} = new_content
    end

    test "puts an identifier if there is not already one and the template has an identifier field",
         %{
           template_with_identifier: template_with_identifier,
           identifier_name: identifier_name,
           domain: domain
         } do
      # Rule has no identifier but its template does
      # This happens if identifier is added to template after rule creation
      # Test an update to the rule in this state.
      %{df_content: content} = rule = insert(:rule, business_concept_id: "123")

      # Just to make sure factory does not add identifier
      refute match?(%{^identifier_name => _identifier}, content)

      params =
        params_for(:rule,
          df_name: template_with_identifier.name,
          df_content: %{"text" => "some update"},
          domain_id: domain.id
        )

      assert %Changeset{changes: changes} = Rule.changeset(rule, params)

      assert %{df_content: new_content} = changes
      assert %{^identifier_name => _identifier} = new_content
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
