defmodule TdQd.QualtityRuleTypeTest do
  use Cabbage.Feature, async: false, file: "quality_rule.feature"
  use TdDqWeb.ConnCase
  import TdDqWeb.Authentication, only: :functions
  import TdDqWeb.QualityControl
  import TdDqWeb.QualityRule
  import TdDqWeb.QualityRuleType
  import TdDqWeb.ResponseCode
  alias TdDqWeb.ApiServices.MockTdAuditService

  setup_all do
    start_supervised MockTdAuditService
    :ok
  end

  defgiven ~r/^user "(?<user_name>[^"]+)" logged in the application$/, %{user_name: user_name}, state do
    token = get_user_token(user_name)
    {:ok,  Map.merge(state, %{status_code: 402, token: token, user_name: user_name})}
  end

  defand ~r/^a existing Quality Control with following data:$/, %{table: table},
    %{token: token} = _state do
      {:ok, status_code, _resp} = create_new_quality_control(token, table)
      assert rc_created() == to_response_code(status_code)
  end

  defand ~r/^a existing Quality Rule Type with name "(?<qr_name>[^"]+)" and the following parameters:$/,
    %{qr_name: qr_name, table: table}, %{token: token} = _state do
     {:ok, _status_code, _resp} = create_new_quality_rule_type(token, %{"name" => qr_name, "params" => table})
  end

  defwhen ~r/^"(?<user_name>[^"]+)" tries to create a Quality Rule associated to Quality Control "(?<qc_name>[^"]+)" and a Quality Rule "(?<qr_name>[^"]+)" with following data:$/, %{user_name: user_name, qc_name: qc_name, qr_name: qr_name, table: table}, state do
    token = state[:token]
    assert user_name == state[:user_name]
    quality_control = find_quality_control(token, %{name: qc_name})
    assert quality_control
    quality_control_id = quality_control["id"]
    {:ok, _status_code, _resp} = create_new_quality_rule(token, %{"quality_control_id" => quality_control_id,
      "type" => qr_name, "params" => table})
  end

  defand ~r/^"(?<user_name>[^"]+)" is able to view a Quality Rule named "(?<qr_name>[^"]+)" with with following data:$/, %{user_name: user_name, qr_name: qr_name, table: _table}, state do
    assert user_name == state[:user_name]
    quality_rule_data = find_quality_rule(state[:token], %{name: qr_name})
    # TODO: check all params
    assert quality_rule_data && quality_rule_data["name"] == qr_name
  end

end
