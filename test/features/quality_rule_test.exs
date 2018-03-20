defmodule TdDq.QualityRuleTest do
  use Cabbage.Feature, async: false, file: "quality_rule.feature"
  use TdDqWeb.ConnCase

  import TdDqWeb.QualityRule
  import TdDqWeb.QualityControl

  import TdDqWeb.ResponseCode
  import TdDqWeb.Authentication, only: :functions

  defgiven ~r/^user "(?<user_name>[^"]+)" is logged in the application$/,
    %{user_name: user_name},
    state do
      token_admin = get_user_token(user_name)
      {:ok,  Map.merge(state, %{token_admin: token_admin})}
  end

  defand ~r/^an existing Quality Control Type called "(?<quality_control_type>[^"]+)" without any parameters$/,
    %{quality_control_type: quality_control_type},
    _state do
      create_empty_quality_control_type(quality_control_type)
  end

  defand ~r/^a Quality Control of type "(?<quality_control_type>[^"]+)" with following data:$/,
    %{quality_control_type: _quality_control_type, table: table},
    %{token_admin: token_admin} = _state do
      {:ok, status_code, _resp} = create_new_quality_control(token_admin, table)
      assert rc_created() == to_response_code(status_code)
  end

  defand ~r/^an existing Quality Rule Type called "(?<rule_type>[^"]+)" without any parameters$/,
    %{rule_type: rule_type},
    _state do
       create_empty_quality_rule_type(rule_type)
  end

  defwhen ~r/^"(?<user_name>[^"]+)" tries to create a Quality Rule of type "(?<quality_rule_type>[^"]+)" associated to Quality Control with Business Concept ID "(?<business_concept_id>[^"]+)" and name "(?<quality_control_name>[^"]+)" with following data:$/,
    %{user_name: user_name, quality_rule_type: _quality_rule_type, business_concept_id: business_concept_id, quality_control_name: quality_control_name, table: table},
    %{token_admin: token_admin} = state do

      quality_control = find_quality_control(token_admin, %{business_concept_id: business_concept_id, name: quality_control_name})
      assert quality_control
      quality_control_id = quality_control["id"]

      token = get_user_token(user_name)
      {:ok, status_code, _resp} = create_new_quality_rule(token, table, quality_control_id)

      {:ok,  Map.merge(state, %{status_code: status_code})}
  end

  defthen ~r/^the system returns a result with code "(?<status_code>[^"]+)"$/,
    %{status_code: status_code},
    state do
      assert status_code == to_response_code(state[:status_code])
  end

  defand ~r/^"(?<user_name>[^"]+)" is able to view Quality Rule of type "(?<quality_rule_type>[^"]+)" and name "(?<quality_rule_name>[^"]+)" associated to Quality Control with Business Concept ID "(?<business_concept_id>[^"]+)" and name "(?<quality_control_name>[^"]+)" with following data:$/,
    %{user_name: user_name, quality_rule_type: quality_rule_type, quality_rule_name: quality_rule_name,
      business_concept_id: business_concept_id, quality_control_name: quality_control_name, table: table},
    %{token_admin: token_admin} = _state do

      quality_control = find_quality_control(token_admin, %{business_concept_id: business_concept_id, name: quality_control_name})
      assert quality_control
      quality_control_id = quality_control["id"]

      found_quality_rule = find_quality_rule(token_admin, %{type: quality_rule_type, name: quality_rule_name, quality_control_id: quality_control_id})
      assert found_quality_rule
      quality_rule_id = found_quality_rule["id"]

      token = get_user_token(user_name)
      {:ok, http_status_code, %{"data" => quality_rule}} = quality_rule_show(token, quality_rule_id)
      assert rc_ok() == to_response_code(http_status_code)
      assert quality_rule["quality_control_id"] == quality_control_id
      attrs = table |> quality_rule_test_fields_to_api
      assert_quality_rule(attrs, quality_rule)

  end

  defp assert_quality_rule(attr, value, %{} = quality_rule), do: assert value == quality_rule[attr]
  defp assert_quality_rule(%{} = attrs, %{} = quality_rule) do
    Enum.each(attrs, fn {attr, value} ->
      assert_quality_rule(attr, value, quality_rule) end)
  end

end
