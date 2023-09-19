defmodule TdDq.RemediationTest do
  use TdDd.DataCase

  alias TdDd.Repo
  alias TdDq.Remediations.Remediation

  @unsafe "javascript:alert(document)"

  setup do
    rule_result = insert(:rule_result)
    %{rule_result: rule_result}
  end

  describe "Remediation.changeset/2" do
    test "validates required fields" do
      assert %{errors: errors} = Remediation.changeset(%{})
      assert {_, [validation: :required]} = errors[:rule_result_id]
      assert {_, [validation: :required]} = errors[:df_name]
      assert {_, [validation: :required]} = errors[:df_content]
    end

    test "captures foreign key constraint on rule result" do
      params = %{
        "df_name" => "template_name",
        "df_content" => %{},
        "rule_result_id" => 12_345
      }

      assert {:error, %{errors: errors}} =
               Remediation.changeset(params)
               |> Repo.insert()

      assert {"does not exist",
              [
                {:constraint, :foreign},
                {:constraint_name, "remediations_rule_result_id_fkey"}
              ]} = errors[:rule_result_id]
    end

    test "can be inserted if valid", %{rule_result: %{id: rule_result_id}} do
      params = %{
        "df_name" => "template_name",
        "df_content" => %{},
        "rule_result_id" => rule_result_id
      }

      assert {:ok, %Remediation{} = remediation} =
               Remediation.changeset(params)
               |> Repo.insert()

      assert %{
               df_name: "template_name",
               df_content: %{},
               rule_result_id: ^rule_result_id
             } = remediation
    end

    test "validates df_content is valid", %{rule_result: %{id: rule_result_id}} do
      %{name: template_name} = CacheHelpers.insert_template(scope: "remediation")

      invalid_content = %{"list" => "foo", "string" => "whatever"}

      params = %{
        "df_name" => template_name,
        "df_content" => invalid_content,
        "rule_result_id" => rule_result_id
      }

      assert %{valid?: false, errors: errors} = Remediation.changeset(params)
      assert {"list: is invalid", _detail} = errors[:df_content]
    end

    test "validates df_content is safe", %{rule_result: %{id: rule_result_id}} do
      %{name: template_name} = CacheHelpers.insert_template(scope: "remediation")

      unsafe_content = %{"list" => "foo", "string" => @unsafe}

      params = %{
        "df_name" => template_name,
        "df_content" => unsafe_content,
        "rule_result_id" => rule_result_id
      }

      assert %{valid?: false, errors: errors} = Remediation.changeset(params)
      assert {"list: is invalid", _detail} = errors[:df_content]
    end
  end
end
