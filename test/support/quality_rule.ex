defmodule TdDqWeb.QualityRule do
  @moduledoc false

  alias Poison, as: JSON
  import TdDqWeb.Router.Helpers
  import TdDqWeb.Authentication, only: :functions
  import TdDqWeb.SupportCommon, only: :functions
  @endpoint TdDqWeb.Endpoint

  @test_quality_rule_table_format %{"Field" => "field", "Type" => "type",
    "Description" => "description", "System" => "system", "Tag" => "tag",
    "Type Params" => "type_params", "System Params" => "system_params", "Name" => "name"}

  def create_new_quality_rule(token, %{"quality_control_id" => quality_control_id,
    "type" => type, "params" => params}) do
     params
     |> field_value_to_api_attrs(@test_quality_rule_table_format)
     |> Map.merge(%{"quality_control_id" => quality_control_id,
        "type" => type})
     |> (&create_quality_rule(token, &1)).()
  end

  defp create_quality_rule(token, params) do
    headers = get_header(token)
    body = %{quality_rule: params} |> JSON.encode!
    %HTTPoison.Response{status_code: status_code, body: resp} =
      HTTPoison.post!(quality_rule_url(@endpoint, :create), body, headers, [])
    {:ok, status_code, resp |> JSON.decode!}
  end

  def find_quality_rule(token, search_params) do
    {:ok, _status_code, json_resp} = quality_rule_list(token)
    Enum.find(json_resp["data"], fn(quality_rule) ->
      Enum.all?(search_params, fn({k, v}) ->
        string_key = Atom.to_string(k)
        quality_rule[string_key] == v
      end
      )
    end
    )
  end

  defp quality_rule_list(token) do
    headers = get_header(token)
    %HTTPoison.Response{status_code: status_code, body: resp} =
      HTTPoison.get!(quality_rule_url(@endpoint, :index), headers, [])
    {:ok, status_code, resp |> JSON.decode!}
  end
end
