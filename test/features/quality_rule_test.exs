defmodule TdQd.QualtityControlTest do
  use Cabbage.Feature, async: false, file: "quality_rule.feature"
  use TdDqWeb.ConnCase
  import TdDqWeb.Authentication, only: :functions
  import TdDqWeb.QualityControl
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

end
