defmodule TdDqWeb.RuleImplementation do
  @moduledoc false

  alias Poison, as: JSON
  import TdDqWeb.Router.Helpers
  import TdDqWeb.Authentication, only: :functions
  import TdDqWeb.SupportCommon, only: :functions
  @endpoint TdDqWeb.Endpoint

  @test_rule_implementation_table_format %{
    "Field" => "field",
    "Type" => "type",
    "System" => "system",
    "Type Params" => "type_params",
    "System Params" => "system_params",
    "Implementation key" => "implementation_key"
  }

  def rule_implementation_create(token, %{"rule_id" => rule_id, "params" => params}) do
    params
    |> field_value_to_api_attrs(@test_rule_implementation_table_format)
    |> Map.merge(%{"rule_id" => rule_id})
    |> (&do_rule_implementation_create(token, &1)).()
  end

  defp do_rule_implementation_create(token, params) do
    headers = get_header(token)
    body = %{rule_implementation: params} |> JSON.encode!()

    %HTTPoison.Response{status_code: status_code, body: resp} =
      HTTPoison.post!(rule_implementation_url(@endpoint, :create), body, headers, [])

    {:ok, status_code, resp |> JSON.decode!()}
  end

  def find_rule_implementation(token, search_params) do
    {:ok, _status_code, json_resp} = rule_implementation_list(token)

    Enum.find(json_resp["data"], fn rule_implementation ->
      Enum.all?(search_params, fn {k, v} ->
        string_key = Atom.to_string(k)
        rule_implementation[string_key] == v
      end)
    end)
  end

  defp rule_implementation_list(token) do
    headers = get_header(token)

    %HTTPoison.Response{status_code: status_code, body: resp} =
      HTTPoison.get!(rule_implementation_url(@endpoint, :index), headers, [])

    {:ok, status_code, resp |> JSON.decode!()}
  end
end
