defmodule TdQd.RuleTypeTest do
  use Cabbage.Feature, async: false, file: "rule_type.feature"
  use TdDqWeb.ConnCase
  import TdDqWeb.Authentication, only: :functions
  import TdDqWeb.RuleType, only: :functions
  import TdDqWeb.ResponseCode, only: :functions

  defgiven ~r/^user "(?<user_name>[^"]+)" logged in the application$/, %{user_name: user_name}, state do
    token = get_user_token(user_name)
    {:ok,  Map.merge(state, %{status_code: 402, token: token, user_name: user_name})}
  end

  defwhen ~r/^"(?<user_name>[^"]+)" tries to create a Rule named "(?<qrt_name>[^"]+)" with following data:$/, %{user_name: user_name, qrt_name: qrt_name, table: table}, state do
    token = state[:token]
    assert user_name == state[:user_name]
    {:ok, status_code, _resp} = create_new_rule_implementation_type(token, %{"name" => qrt_name, "params" => table})
    {:ok,  Map.merge(state, %{status_code: status_code})}
  end

  defthen ~r/^the system returns a result with code "(?<status_code>[^"]+)"$/, %{status_code: status_code}, state do
    assert status_code == to_response_code(state[:status_code])
  end

  defand ~r/^"(?<user_name>[^"]+)" is able to view rule type named "(?<qrt_name>[^"]+)" with following data:$/, %{user_name: user_name, qrt_name: qrt_name}, state do
    assert user_name == state[:user_name]
    rule_type_data = find_rule_type(state[:token], %{name: qrt_name})
    # TODO: check all params
    assert rule_type_data && rule_type_data["name"] == qrt_name
  end

end
