defmodule TdDq.Remediations.RemediationsTest do
  use TdDd.DataCase

  alias TdDq.Remediations
  alias TdDq.Remediations.Remediation

  @valid_attrs %{"df_name" => "template_name", "df_content" => %{}}

  setup do
    remediation_template = %{
      name: "remediation_template",
      label: "remediation_template",
      scope: "remediation",
      content: [
        %{
          "name" => "grupo_principal",
          "fields" => [
            %{
              "name" => "texto",
              "type" => "string",
              "label" => "Text",
              "values" => nil,
              "widget" => "string",
              "default" => "",
              "cardinality" => "?",
              "description" => "texto"
            }
          ]
        }
      ]
    }

    CacheHelpers.insert_template(remediation_template)
    %{template: remediation_template}
  end

  describe "remediations" do
    test "list_remediations/1 returns all remediations", %{template: %{name: df_name}} do
      %{id: id} = insert(:rule_result)
      remediation_1 = insert(:remediation, df_name: df_name, rule_result_id: id)
      remediation_2 = insert(:remediation, df_name: df_name, rule_result_id: id)
      assert [remediation_1, remediation_2] == Remediations.list_remediations()
    end

    test "get_remediations/1 returns the remediation with given id", %{template: %{name: df_name}} do
      %{id: id} = insert(:rule_result)

      %{id: remediation_id} =
        remediation = insert(:remediation, df_name: df_name, rule_result_id: id)

      assert remediation == Remediations.get_remediation(remediation_id)
    end

    test "get_remediations/1 returns the remediation with given id and its preloads", %{
      template: %{name: df_name}
    } do
      %{id: implementation_id} = insert(:implementation, domain_id: 1)
      %{id: rule_result_id} = insert(:rule_result, implementation_id: implementation_id)

      %{id: remediation_id} =
        insert(:remediation, df_name: df_name, rule_result_id: rule_result_id)

      assert %{
               id: ^remediation_id,
               rule_result: %{
                 id: ^rule_result_id,
                 implementation: %{
                   id: ^implementation_id,
                   domain_id: 1
                 }
               }
             } =
               Remediations.get_remediation(remediation_id,
                 preload: [rule_result: :implementation]
               )
    end

    test "get_remediations/1 returns nil if not found" do
      assert nil == Remediations.get_remediation(-1)
    end

    test "create_remediation/2 creates a remediation" do
      %{id: id} = insert(:rule_result, implementation: build(:implementation))
      %{user_id: claims_user_id} = claims = build(:claims)

      assert {
               :ok,
               %{
                 remediation: %Remediation{
                   rule_result_id: rule_result_id,
                   df_name: df_name,
                   df_content: df_content,
                   user_id: user_id
                 }
               }
             } = Remediations.create_remediation(id, @valid_attrs, claims)

      assert rule_result_id == id
      assert df_name == @valid_attrs["df_name"]
      assert df_content == @valid_attrs["df_content"]
      assert user_id == claims_user_id
    end

    test "creation publishes audit event" do
      %{id: id} = insert(:rule_result, implementation: build(:implementation))
      claims = build(:claims)

      assert {:ok, %{audit: audit}} = Remediations.create_remediation(id, @valid_attrs, claims)

      refute is_nil(audit)
    end

    test "update_remediation/2 updates a remediation", %{template: %{name: df_name}} do
      %{id: id} = insert(:rule_result)

      remediation = insert(:remediation, df_name: df_name, rule_result_id: id)

      %{user_id: new_user_id} = claims = build(:claims)

      assert {
               :ok,
               %Remediation{
                 df_content: %{"text" => "some_text"},
                 user_id: ^new_user_id
               }
             } =
               Remediations.update_remediation(
                 remediation,
                 %{
                   "df_content" => %{"text" => "some_text"}
                 },
                 claims
               )
    end
  end
end
