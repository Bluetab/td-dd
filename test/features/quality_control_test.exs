defmodule TrueBG.AuthenticationTest do
  use Cabbage.Feature, async: false, file: "quality_control.feature"
  use DataQualityWeb.ConnCase
  import DataQualityWeb.Router.Helpers
  import DataQualityWeb.ResponseCode
  import DataQualityWeb.Authentication, only: :functions
  alias Poison, as: JSON
  @endpoint DataQualityWeb.Endpoint

  # Scenario

  defgiven ~r/^user "(?<user_name>[^"]+)" is logged in the application$/, %{user_name: user_name}, state do
    {:ok, token, _full_claims} = sign_in(user_name)
    {:ok,  Map.merge(state, %{status_code: 402, token: token, user_name: user_name})}
  end

  defwhen ~r/^"(?<user_name>[^"]+)" tries to create a Quality Control of type "(?<type>[^"]+)" with following data:$/,
    %{user_name: user_name, type: _type, table: table}, state do

    assert user_name == state[:user_name]
    attrs = field_value_to_api_attrs(table,
      %{"Field" => "field", "Type" => "type", "Business Concept ID" => "business_concept_id",
        "Name" => "name", "Description" => "description", "Weight" => "weight",
        "Priority" => "priority", "Population" => "population", "Goal" => "goal", "Minimum" => "minimum"
      }
    )
    attrs = %{attrs |
      "weight" => String.to_integer(attrs["weight"]),
      "goal" => String.to_integer(attrs["goal"]),
      "minimum" => String.to_integer(attrs["minimum"])
    }
    {:ok, status_code, json_resp} = quality_control_create(state[:token], attrs)
    quality_control_json = json_resp["data"]
    Enum.map(attrs, fn({k, _v}) ->
              assert attrs[k] == quality_control_json[k]
              end
            )
   {:ok,  Map.merge(state, %{status_code: status_code})}
  end

  defthen ~r/^the system returns a result with code "(?<status_code>[^"]+)"$/, %{status_code: status_code}, state do
    assert status_code == to_response_code(state[:status_code])
  end

  defand ~r/^"(?<user_name>[^"]+)" is able to view quality control with Business Concept ID "(?<business_concept_id>[^"]+)" and name "(?<name>[^"]+)" with following data:$/,
    %{user_name: user_name, business_concept_id: _business_concept_id, name: _name}, state do

    assert user_name == state[:user_name]

  end

  defp field_value_to_api_attrs(table, key_alias_map) do
    table
    |> Enum.reduce(%{}, fn(x, acc) ->
        Map.put(acc, Map.get(key_alias_map,  x."Field", x."Field"), x."Value")
        end
       )
  end

  def quality_control_create(token, quality_control_params) do
    headers = get_header(token)
    body = %{quality_control: quality_control_params} |> JSON.encode!
    %HTTPoison.Response{status_code: status_code, body: resp} =
      HTTPoison.post!(quality_control_url(@endpoint, :create), body, headers, [])
    {:ok, status_code, resp |> JSON.decode!}
  end
  
end
