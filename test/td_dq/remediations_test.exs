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
    test "create_remediation/2 creates a remediation" do
      %{id: id} = insert(:rule_result, implementation: build(:implementation))
      claims = build(:claims)

      assert {
               :ok,
               %{remediation: %Remediation{
                 rule_result_id: rule_result_id,
                 df_name: df_name,
                 df_content: df_content
               }}
             } = Remediations.create_remediation(id, @valid_attrs, claims)

      assert rule_result_id == id
      assert df_name == @valid_attrs["df_name"]
      assert df_content == @valid_attrs["df_content"]
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

      assert {
               :ok,
               %Remediation{
                 df_content: %{text: "some_text"}
               }
             } = Remediations.update_remediation(remediation, %{df_content: %{text: "some_text"}})
    end
  end
end
