defmodule TdQd.RuleImplementationTest do
  use Cabbage.Feature, async: false, file: "rule_implementation.feature"
  use TdDqWeb.ConnCase
  import TdDqWeb.Authentication, only: :functions
  import TdDqWeb.Rule
  import TdDqWeb.RuleImplementation
  import TdDqWeb.RuleType
  import TdDqWeb.ResponseCode
  alias TdDqWeb.ApiServices.MockTdAuditService

  setup_all do
    start_supervised(MockTdAuditService)
    :ok
  end

  defgiven ~r/^user "(?<user_name>[^"]+)" logged in the application$/,
           %{user_name: user_name},
           state do
    token = get_user_token(user_name)
    {:ok, Map.merge(state, %{status_code: 402, token: token, user_name: user_name})}
  end

  defand ~r/^a existing Rule with following data:$/,
         %{table: table},
         %{token: token} = _state do
    {:ok, status_code, _resp} = create_new_rule(token, table)
    assert rc_created() == to_response_code(status_code)
  end

  defand ~r/^a existing Rule Type with name "(?<qr_name>[^"]+)" and the following parameters:$/,
         %{qr_name: qr_name, table: table},
         %{token: token} = _state do
    {:ok, _status_code, _resp} =
      create_new_rule_implementation_type(token, %{"name" => qr_name, "params" => table})
  end

  defwhen ~r/^"(?<user_name>[^"]+)" tries to create a Rule Implementation associated to Rule "(?<qc_name>[^"]+)" with following data:$/,
          %{user_name: user_name, qc_name: qc_name, table: table},
          state do
    token = state[:token]
    assert user_name == state[:user_name]
    rule = find_rule(token, %{name: qc_name})
    assert rule
    rule_id = rule["id"]

    {:ok, status_code, _resp} =
      create_new_rule_implementation(token, %{
        "rule_id" => rule_id,
        "params" => table
      })

    {:ok, Map.merge(state, %{status_code: status_code})}
  end

  defand ~r/^"(?<user_name>[^"]+)" is able to view a Rule Implementation named "(?<qr_name>[^"]+)" with following data:$/,
         %{user_name: user_name, qr_name: qr_name, table: _table},
         state do
    assert user_name == state[:user_name]
    rule_implementation_data = find_rule_implementation(state[:token], %{name: qr_name})
    # TODO: check all params
    assert rule_implementation_data && rule_implementation_data["name"] == qr_name
  end

  defwhen ~r/^"(?<user_name>[^"]+)" tries to create a Rule Implementation associated to Rule "(?<qc_name>[^"]+)" without an existing Rule Implementation type and the following data:$/,
          %{user_name: user_name, qc_name: qc_name, table: table},
          state do
    token = state[:token]
    assert user_name == state[:user_name]
    rule = find_rule(token, %{name: qc_name})
    assert rule
    rule_id = rule["id"]

    {:ok, status_code, _resp} =
      create_new_rule_implementation(token, %{
        "rule_id" => rule_id,
        "params" => table
      })

    {:ok, Map.merge(state, %{status_code: status_code})}
  end

  defthen ~r/^the system returns a result with code "(?<status_code>[^"]+)"$/,
          %{status_code: status_code},
          state do
    assert status_code == to_response_code(state[:status_code])
  end
end
