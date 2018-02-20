defmodule DataDictionary.DictionaryTest do
  use Cabbage.Feature, async: false, file: "dictionary.feature"
  use DataDictionaryWeb.ConnCase

  import DataDictionaryWeb.Router.Helpers
  import DataDictionaryWeb.ResponseCode
  import DataDictionaryWeb.Authentication, only: :functions

  alias Poison, as: JSON

  @endpoint DataDictionaryWeb.Endpoint
  @headers {"Content-type", "application/json"}
  @fixed_data_structure_values %{"System" => "system",
                                 "Group" => "group",
                                 "Name" => "name",
                                 "Description" => "description",
                                 "Last Modification" => "last_change",
                                 "Last User" => "modifier",
                                }
  @fixed_data_field_values %{"Field Name" => "name",
                             "Type" => "type",
                             "Precision" => "precision",
                             "Nullable" => "nullable",
                             "Business Concept ID" => "business_concept_id",
                             "Description" => "description",
                             "Last Modification" => "last_change",
                             "Last User" => "modifier",
                            }

#   Scenario: Create a new Data Structure

  defwhen ~r/^"(?<user_name>[^"]+)" tries to create a Data Structure with following data:$/,
    %{user_name: user_name, table: fields}, state do
      token = get_user_token(user_name)
      attrs = field_value_to_api_attrs(fields, @fixed_data_structure_values)
      {:ok, status_code, _} = data_structure_create(token, attrs)
      {:ok, Map.merge(state, %{status_code: status_code})}
  end

  defthen ~r/^the system returns a result with code "(?<status_code>[^"]+)"$/,
          %{status_code: status_code}, %{status_code: http_status_code} do
    assert status_code == to_response_code(http_status_code)
  end

  defand ~r/^"(?<user_name>[^"]+)" is able to view data structure system "(?<system>[^"]+)" group "(?<group>[^"]+)" and structure "(?<structure>[^"]+)"  with following data:$/,
    %{user_name: user_name, system: system, group: group, structure: structure, table: fields},
    _state do
      token = get_user_token(user_name)
      attrs = field_value_to_api_attrs(fields, @fixed_data_structure_values)
      data_structure_tmp = data_structure_find(token, system, group, structure)
      assert data_structure_tmp
      {:ok, http_status_code, %{"data" => data_structure}} =
        data_structure_show(token, data_structure_tmp["id"])
      assert rc_ok() == to_response_code(http_status_code)
      assert_attrs(attrs, data_structure)
  end

  #Scenario: Create a new field related to an existing Data Structure inside Data Dictionary

  defgiven ~r/^and existing data structure with following data:$/,
    %{table: fields}, state do
      token_admin = get_user_token("app-admin")
      attrs = field_value_to_api_attrs(fields, @fixed_data_structure_values)
      {:ok, http_status_code, _} = data_structure_create(token_admin, attrs)
      assert rc_created() == to_response_code(http_status_code)
      {:ok, Map.merge(state, %{token_admin: token_admin})}
  end

  defwhen ~r/^"(?<user_name>[^"]+)" tries to create a Data Field from system "(?<system>[^"]+)" group "(?<group>[^"]+)" and structure "(?<structure>[^"]+)" with following data:$/,
    %{user_name: user_name, system: system, group: group, structure: structure, table: fields},
    %{token_admin: token_admin} = state do
      data_structure = data_structure_find(token_admin, system, group, structure)
      attrs = fields
      |> field_value_to_data_field
      |> Map.put("data_structure_id", data_structure["id"])
      token = get_user_token(user_name)
      {:ok, status_code, _} = data_field_create(token, attrs)
      {:ok, Map.merge(state, %{status_code: status_code})}
  end

  defand ~r/^"(?<user_name>[^"]+)" is able to view data field "(?<field_name>[^"]+)" from system "(?<system>[^"]+)" group "(?<group>[^"]+)" and structure "(?<structure>[^"]+)" with following data:$/,
    %{user_name: user_name, field_name: field_name, system: system, group: group, structure: structure, table: fields},
    %{token_admin: token_admin} = _state do
      data_structure = data_structure_find(token_admin, system, group, structure)
      data_field_tmp = data_field_find(token_admin, field_name)
      assert data_field_tmp
      token = get_user_token(user_name)
      {:ok, http_status_code, %{"data" => data_field}} = data_field_show(token, data_field_tmp["id"])
      assert rc_ok() == to_response_code(http_status_code)
      assert data_field["data_structure_id"] == data_structure["id"]
      attrs = field_value_to_data_field(fields)
      assert_attrs(attrs, data_field)
  end

  defp field_value_to_data_field(field_value) do
    field_value
    |> field_value_to_api_attrs(@fixed_data_field_values)
    |> Map.update("nullable", false, &(&1 == "YES"))
    |> Map.update("precision", 0, &String.to_integer(&1))
    |> Map.update("business_concept_id", nil, &(if &1 == "", do: nil, else: String.to_integer(&1)))
  end

  defp field_value_to_api_attrs(field_value, fixed_values) do
    Enum.reduce(field_value, %{}, fn(x, acc) -> Map.put(acc, Map.get(fixed_values, x."Field", x."Field"), x."Value") end)
  end

  defp assert_attr("last_change" = attr, _value, %{} = target) do
    assert :ok == elem(DateTime.from_iso8601(target[attr]), 0)
  end

  defp assert_attr("nullable" = attr, value, %{} = target) do
    assert target[attr] == (value == "YES")
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

  defp data_structure_find(token, system, group, name) do
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

  defp data_field_create(token, attrs) do
    headers = [@headers, {"authorization", "Bearer #{token}"}]
    body = %{"data_field" => attrs} |> JSON.encode!
    %HTTPoison.Response{status_code: status_code, body: resp} =
        HTTPoison.post!(data_field_url(@endpoint, :create), body, headers, [])
    {:ok, status_code, resp |> JSON.decode!}
  end

  defp data_field_show(token, id) do
    headers = [@headers, {"authorization", "Bearer #{token}"}]
    %HTTPoison.Response{status_code: status_code, body: resp} =
        HTTPoison.get!(data_field_url(@endpoint, :show, id), headers, [])
    {:ok, status_code, resp |> JSON.decode!}
  end

  defp data_field_find(token, name) do
    {:ok, _, %{"data" => data_structure}} = data_field_index(token)
    Enum.find(data_structure, &(&1["name"] == name))
  end

  defp data_field_index(token) do
    headers = get_header(token)
    %HTTPoison.Response{status_code: status_code, body: resp} =
      HTTPoison.get!(data_field_url(@endpoint, :index), headers, [])
    {:ok, status_code, resp |> JSON.decode!}
  end

end
