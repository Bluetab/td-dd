defmodule TdDq.RemediationTest do
  use TdDd.DataCase

  alias Ecto.Changeset
  alias TdDq.Remediations.Remediation
  alias TdDd.Repo

  setup do

    rule_result = insert(:rule_result)
    # %{external_id: data_structure_external_id} = insert(:data_structure)
    # user = CacheHelpers.insert_user()

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
        "rule_result_id" => 12345
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

    test "can be inserted if valid", %{
      rule_result: %{id: rule_result_id}
    } do
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


  end
end
