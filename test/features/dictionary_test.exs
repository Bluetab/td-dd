defmodule DataDictionary.DictionaryTest do
  use Cabbage.Feature, async: false, file: "dictionary.feature"
  use DataDictionaryWeb.ConnCase

  import DataDictionaryWeb.Router.Helpers
  import DataDictionaryWeb.ResponseCode
  import DataDictionaryWeb.Authentication, only: :functions

  alias Poison, as: JSON

  @endpoint DataDictionaryWeb.Endpoint
  @headers {"Content-type", "application/json"}
  @fixed_values %{"System" => "system",
                  "Group" => "group",
                  "Name" => "name",
                  "Description" => "description",
                  "Last Modification" => "last_change",
                  "Last User" => "modifier",
                  }

#   Scenario: Create a new Data Structure

  defwhen ~r/^"(?<user_name>[^"]+)" tries to create a Data Structure with following data:$/,
    %{user_name: user_name, table: fields}, state do
      token = get_user_token(user_name)
      attrs = field_value_to_api_attrs(fields, @fixed_values)
      {:ok, status_code, _} = data_structure_create(token, attrs)
      {:ok, Map.merge(state, %{status_code: status_code})}
  end

  defthen ~r/^the system returns a result with code "(?<status_code>[^"]+)"$/,
          %{status_code: status_code}, %{status_code: http_status_code} do
    assert status_code == to_response_code(http_status_code)
  end

  defand ~r/^"(?<user_name>[^"]+)" is able to view data structure with following data:$/,
    %{user_name: user_name, table: fields}, _state do
      token = get_user_token(user_name)
      attrs = field_value_to_api_attrs(fields, @fixed_values)
      data_structure_tmp = data_structure_find(token, attrs["system"],
                                               attrs["group"], attrs["name"])
      assert data_structure_tmp
      {:ok, http_status_code, %{"data" => data_structure}} =
        data_structure_show(token, data_structure_tmp["id"])
      assert rc_ok() == to_response_code(http_status_code)
      assert_attrs(attrs, data_structure)
  end

  defp field_value_to_api_attrs(table, fixed_values) do
    table
      |> Enum.reduce(%{}, fn(x, acc) -> Map.put(acc, Map.get(fixed_values, x."Field", x."Field"), x."Value") end)
  end

  defp assert_attr("last_change" = attr, _value, %{} = target) do
    assert :ok == elem(DateTime.from_iso8601(target[attr]), 0)
  end

  defp assert_attr("modifier" = attr, _value, %{} = target) do
    assert target[attr] != nil
  end

  defp assert_attr(attr, value, %{} = target) do
    assert value == target[attr]
  end

  defp assert_attrs(%{} = attrs, %{} = target) do
    Enum.each(attrs, fn {attr, value} -> assert_attr(attr, value, target) end)
  end

  defp data_structure_create(token, attrs) do
    headers = [@headers, {"authorization", "Bearer #{token}"}]
    body = %{"data_structure" => attrs} |> JSON.encode!
    %HTTPoison.Response{status_code: status_code, body: resp} =
        HTTPoison.post!(data_structure_url(@endpoint, :create), body, headers, [])
    {:ok, status_code, resp |> JSON.decode!}
  end

  defp data_structure_show(token, id) do
    headers = [@headers, {"authorization", "Bearer #{token}"}]
    %HTTPoison.Response{status_code: status_code, body: resp} =
        HTTPoison.get!(data_structure_url(@endpoint, :show, id), headers, [])
    {:ok, status_code, resp |> JSON.decode!}
  end

  def data_structure_find(token, system, group, name) do
    {:ok, _, %{"data" => data_structure}} = data_structure_index(token)
    Enum.find(data_structure, &(&1["system"] == system &&
                                &1["group"] == group &&
                                &1["name"] == name))
  end

  defp data_structure_index(token) do
    headers = get_header(token)
    %HTTPoison.Response{status_code: status_code, body: resp} =
      HTTPoison.get!(data_structure_url(@endpoint, :index), headers, [])
    {:ok, status_code, resp |> JSON.decode!}
  end

end
