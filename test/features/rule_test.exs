defmodule TdQd.RuleTest do
  use Cabbage.Feature, async: false, file: "rule.feature"
  use TdDqWeb.ConnCase
  import TdDqWeb.Authentication, only: :functions
  import TdDqWeb.Rule, only: :functions
  import TdDqWeb.ResponseCode, only: :functions
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

  defwhen ~r/^"(?<user_name>[^"]+)" tries to create a Quality Control with following data:$/,
          %{user_name: user_name, table: table},
          state do
    assert user_name == state[:user_name]
    {:ok, status_code, _resp} = create_new_quality_control(state[:token], table)
    {:ok, Map.merge(state, %{status_code: status_code})}
  end

  defwhen ~r/^"(?<user_name>[^"]+)" tries to create a Quality Control of type (?<type>[^"]+) with following data and type_params (?<type_params>%-{.*}):$/,
          %{user_name: user_name, type: type, type_params: type_params, table: table},
          state do
    assert user_name == state[:user_name]

    table =
      table ++ [%{Field: "Type", Value: type}] ++ [%{Field: "Type Params", Value: type_params}]

    {:ok, status_code, _resp} = create_new_quality_control(state[:token], table)
    {:ok, Map.merge(state, %{status_code: status_code})}
  end

  defthen ~r/^the system returns a result with code "(?<status_code>[^"]+)"$/,
          %{status_code: status_code},
          state do
    assert status_code == to_response_code(state[:status_code])
  end

  defand ~r/^"(?<user_name>[^"]+)" is able to view quality control named "(?<qc_name>[^"]+)" with with following data:$/,
         %{user_name: user_name, qc_name: qc_name, table: table},
         state do
    assert user_name == state[:user_name]
    quality_control_data = find_quality_control(state[:token], %{name: qc_name})

    attrs =
      table
      |> quality_control_test_fields_to_api_create_and_get_alias
      |> cast_quality_control_integer_fields_plus_version

    assert_attrs(attrs, quality_control_data)
  end

  defand ~r/^a existing Quality Rule Type with name "(?<qr_name>[^"]+)" and the following parameters:$/,
         %{qr_name: qr_name, table: table},
         %{token: token} = _state do
    {:ok, _status_code, _resp} =
      create_new_quality_rule_type(token, %{"name" => qr_name, "params" => table})
  end

  def assert_attr(attr, value, %{} = target) do
    assert value == target[attr]
  end

  defp assert_attrs(nil, nil) do
    true
  end

  defp assert_attrs(%{} = attrs, %{} = target) do
    Enum.each(attrs, fn {attr, value} ->
      assert_attr(attr, value, target)
    end)
  end
end
