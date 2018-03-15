defmodule TrueBG.AuthenticationTest do
  use Cabbage.Feature, async: false, file: "quality_control.feature"
  use TdDqWeb.ConnCase
  import TdDqWeb.Router.Helpers
  import TdDqWeb.ResponseCode
  import TdDqWeb.Authentication, only: :functions
  alias Poison, as: JSON
  @endpoint TdDqWeb.Endpoint

  @test_to_api_create_alias %{"Field" => "field", "Type" => "type", "Business Concept ID" => "business_concept_id",
    "Name" => "name", "Description" => "description", "Weight" => "weight",
    "Priority" => "priority", "Population" => "population", "Goal" => "goal", "Minimum" => "minimum"
  }

  @test_to_api_get_alias %{"Status" => "status", "Last User" => "updated_by", "Version" => "version", "Last Modification" => "inserted_at"}

  @quality_control_integer_fields ["weight", "goal", "minimum"]

  # Scenario: Create a new Quality Control with only generic fields
  defgiven ~r/^user "(?<user_name>[^"]+)" is logged in the application$/, %{user_name: user_name}, state do
    # {:ok, token, _full_claims} = sign_in(user_name) OLD
    token = get_user_token(user_name)
    {:ok,  Map.merge(state, %{status_code: 402, token: token, user_name: user_name})}
  end

  defwhen ~r/^"(?<user_name>[^"]+)" tries to create a Quality Control of type "(?<type>[^"]+)" with following data:$/,
    %{user_name: user_name, type: type, table: table}, state do

    assert user_name == state[:user_name]
    assert type == state[:qc_type]
    attrs = table
    |> field_value_to_api_attrs(@test_to_api_create_alias)

    attrs = attrs
    |> cast_to_int_attrs(@quality_control_integer_fields)
    {:ok, status_code, _json_resp} = quality_control_create(state[:token], attrs)
    {:ok,  Map.merge(state, %{status_code: status_code})}
  end

  defthen ~r/^the system returns a result with code "(?<status_code>[^"]+)"$/, %{status_code: status_code}, state do
    assert status_code == to_response_code(state[:status_code])
  end

  def assert_attr("type_params" = attr, value, %{} = target) do
    assert_attrs(value, target[attr])
  end

  def assert_attr("inserted_at" = attr, _value, %{} = _target) do
    assert attr != nil
  end

  def assert_attr(attr, value, %{} = target) do
    assert value == target[attr]
  end

  defp assert_attrs(nil, nil) do
    true
  end

  defp assert_attrs(%{} = attrs, %{} = target) do
    Enum.each(attrs, fn {attr, value} ->
      assert_attr(attr, value, target) end)
  end

  defand ~r/^"(?<user_name>[^"]+)" is able to view quality control with Business Concept ID "(?<business_concept_id>[^"]+)" and name "(?<name>[^"]+)" with following data:$/,
    %{user_name: user_name, business_concept_id: business_concept_id,
      name: name, table: table}, state do

    assert user_name == state[:user_name]
    quality_control_data = get_quality_control(state[:token], %{business_concept_id: business_concept_id, name: name})

    attrs = table
    |> field_value_to_api_attrs(Map.merge(@test_to_api_create_alias, @test_to_api_get_alias))
    |> cast_to_int_attrs(@quality_control_integer_fields ++ ["version"])

    assert_attrs(attrs, quality_control_data)

  end

  defand ~r/^an existing Quality Control type called "(?<quality_control_type>[^"]+)" without any parameters$/,
    %{quality_control_type: quality_control_type},
    state do
    assert quality_control_type

    json_schema = [%{"type_name": quality_control_type, "type_description": "", "type_parameters": nil}] |> JSON.encode!

    file_name = Application.get_env(:td_dq, :qc_types_file)
    file_path = Path.join(:code.priv_dir(:td_dq), file_name)
    File.write!(file_path, json_schema, [:write, :utf8])

    {:ok,  Map.merge(state, %{qc_type: quality_control_type})}
  end

  defand ~r/^an existing Quality Control type called "(?<type_name>[^"]+)" with description "(?<description>[^"]+)" and following parameters:$/,
    %{type_name: type_name, description: description, table: table},
    state do

      parameters = Enum.map(table, fn(row) ->
        Map.new
        |> Map.put("name", String.trim(row[:Parameter]))
        |> Map.put("type", String.trim(row[:Type]))
      end)
      json_schema = [%{"type_name": type_name, "type_description": description, "type_parameters": parameters}] |> JSON.encode!

      file_name = Application.get_env(:td_dq, :qc_types_file)
      file_path = Path.join(:code.priv_dir(:td_dq), file_name)
      File.write!(file_path, json_schema, [:write, :utf8])

      {:ok, Map.merge(state, %{qc_type: type_name})}

  end

  # Scenario: Receive and store results data for existing Quality Controls in bulk mode
  defgiven ~r/^some quality controls exist in the system with following data:$/,
    %{table: table}, state do
      token_admin = get_user_token("app-admin")
      quality_controls_create(token_admin, table)
      {:ok, Map.merge(state, %{token_admin: token_admin})}
  end

  defwhen ~r/^"(?<user_name>[^"]+)" tries to load quality controls results with following information:$/,
    %{table: table}, %{token_admin: token_admin} = _state do
      quality_controls_results =
      []
      |> parse_table_to_csv(Enum.reverse(table))
      |> CSV.encode |> Enum.to_list |> Enum.join
      {:ok, 200, ""} = results_upload(quality_controls_results, token_admin)
  end

  defthen ~r/^"(?<user_name>[^"]+)" is able to view quality control results for Business Concept ID "(?<business_concept_id>[^"]+)" with following data:$/,
    %{business_concept_id: business_concept_id, table: table},
    %{token_admin: token_admin} = _state do
      results_list = quality_controls_results_list(token_admin, business_concept_id)
      Enum.each(Enum.zip(results_list, table), fn(tuple_to_compare) ->
                tuple_to_compare = put_elem(tuple_to_compare, 0, Map.update(elem(tuple_to_compare, 0), "date", nil, &(Enum.at(String.split(&1, "T", parts: 2), 0))))
                Enum.each(elem(tuple_to_compare, 1), fn({k, v}) ->
                            assert to_string(elem(tuple_to_compare, 0)[to_string(k)]) == v
                          end
                          )
              end
              )
  end

  defp quality_controls_results_list(token, business_concept_id) do
      {:ok, 200, %{"data" => list_quality_controls}} = quality_controls_results_list(token)
      Enum.filter(list_quality_controls, fn(x) -> x["business_concept_id"] == business_concept_id end)
  end

  defp results_upload(quality_controls_results, token) do
    headers = get_header(token)
    form = [{
              "file",
              quality_controls_results,
              {"form-data", [{"name", "quality_controls_results"}, {"filename", "quality_controls_results.csv"}]},
              [{"Content-Type", "text/csv"}]
          }]
    %HTTPoison.Response{status_code: status_code, body: _resp}
       = HTTPoison.post!(quality_controls_results_url(@endpoint, :upload), {:multipart, form}, headers, [])
    {:ok, status_code, ""}
  end

  defp quality_controls_results_list(token) do
    headers = get_header(token)
    %HTTPoison.Response{status_code: status_code, body: resp} =
      HTTPoison.get!(quality_controls_results_url(@endpoint, :index), headers, [])
    {:ok, status_code, resp |> JSON.decode!}
  end

  defp parse_table_to_csv(table, [head|tail]) do
    table
    |> parse_table_to_csv(head)
    |> parse_table_to_csv(tail)
  end
  defp parse_table_to_csv(table, %{business_concept_id: bc_id, date: date, field_name: field,
                                group: group, quality_control_name: quality_control,
                                result: result, structure_name: name, system: system}) do
    [[bc_id, date, field, group, quality_control, result, name, system] | table]
  end
  defp parse_table_to_csv(table, []), do: table

  defp quality_controls_create(token, table) do
    Enum.each(table, fn(quality_control) ->
      {:ok, 201, json_resp} = quality_control_create(token, quality_control)
      quality_control_json = json_resp["data"]
      Enum.each(quality_control, fn({k, _v}) ->
                assert quality_control[k] == to_string(quality_control_json[to_string(k)])
                end
              )
    end
    )
  end
  ######################################################################################################

  def cast_to_int_attrs(m, keys) do
    m
    |> Map.split(keys)
    |> fn({l1, l2}) ->
        l1 |>
        Enum.map(fn({k, v}) ->
          {k, String.to_integer(v)} end
        )
        |> Enum.into(l2)
       end.()
  end

  defp get_quality_control(token, search_params) do
    {:ok, _status_code, json_resp} = quality_control_list(token)
    Enum.find(json_resp["data"], fn(quality_control) ->
      Enum.all?(search_params, fn({k, v}) ->
        string_key = Atom.to_string(k)
        quality_control[string_key] == v
      end
      )
    end
    )
  end

  defp field_value_to_api_attrs(table, key_alias_map) do
    attrs_map = table
    |> Enum.reduce(%{}, fn(x, acc) -> Map.put(acc, Map.get(key_alias_map, x."Field", x."Field"), x."Value") end)
    |> Map.split(Map.values(key_alias_map))
    |> fn({f, v}) -> Map.put(f, "type_params", v) end.()

    if attrs_map["type_params"] == %{} do
      attrs_map = Map.put(attrs_map, "type_params", nil)
      attrs_map
    else
      attrs_map
    end
  end

  defp quality_control_list(token) do
    headers = get_header(token)
    %HTTPoison.Response{status_code: status_code, body: resp} =
      HTTPoison.get!(quality_control_url(@endpoint, :index), headers, [])
    {:ok, status_code, resp |> JSON.decode!}
  end

  defp quality_control_create(token, quality_control_params) do
    headers = get_header(token)
    body = %{quality_control: quality_control_params} |> JSON.encode!
    %HTTPoison.Response{status_code: status_code, body: resp} =
      HTTPoison.post!(quality_control_url(@endpoint, :create), body, headers, [])
    {:ok, status_code, resp |> JSON.decode!}
  end
end
