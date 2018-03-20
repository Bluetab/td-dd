defmodule TdQd.QualtityControlTest do
  use Cabbage.Feature, async: false, file: "quality_control.feature"
  use TdDqWeb.ConnCase

  import TdDqWeb.QualityControl

  import TdDqWeb.Router.Helpers
  import TdDqWeb.ResponseCode
  import TdDqWeb.Authentication, only: :functions
  alias Poison, as: JSON
  @endpoint TdDqWeb.Endpoint

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

    {:ok, status_code, _resp} = create_new_quality_control(state[:token], table)

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

  def assert_attr("updated_by" = attr, _value, %{} = target) do
    assert target[attr] != nil
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
    quality_control_data = find_quality_control(state[:token], %{business_concept_id: business_concept_id, name: name})

    attrs = table
    |> quality_control_test_fields_to_api_create_and_get_alias
    |> cast_quality_control_integer_fields_plus_version

    assert_attrs(attrs, quality_control_data)

  end

  defand ~r/^an existing Quality Control type called "(?<quality_control_type>[^"]+)" without any parameters$/,
    %{quality_control_type: quality_control_type},
    state do
    assert quality_control_type
    create_empty_quality_control_type(quality_control_type)
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

  defand ~r/^an existing quality control types:$/, %{table: table}, _state do
    quality_control_types = get_quality_control_types_from_table(table)
    json_schema = quality_control_types |> JSON.encode!
    file_name = Application.get_env(:td_dq, :qc_types_file)
    file_path = Path.join(:code.priv_dir(:td_dq), file_name)
    File.write!(file_path, json_schema, [:write, :utf8])
  end

  defwhen ~r/^"(?<user_name>[^"]+)" tries to list quality control types$/,
    %{user_name: user_name},
    state do
    token = get_user_token(user_name)
    {:ok, status_code, %{"data" => resp}} = quality_control_type_list(token)
    {:ok, Map.merge(state, %{status_code: status_code, quality_controls_types: resp})}
  end

  defand ~r/^"(?<user_name>[^"]+)" is able to view quality control types:$/,
    %{user_name: _user_name, table: table},
    %{quality_controls_types: quality_controls_types} = _state do
      expected_quality_control_types = Enum.reduce(table, [], &(&2 ++ [&1[:Name]]))
      retrieved_quality_control_types = Enum.reduce(quality_controls_types, [], &(&2 ++ [&1["type_name"]]))
      assert expected_quality_control_types == retrieved_quality_control_types
  end

  defp get_quality_control_types_from_table(table) do
    Enum.reduce(table, [], fn(row, acc) ->
      type_name = Map.get(row, :Name)
      if type_name == "" do
        {last_map, acc} = List.pop_at(acc, -1)
        parameter_ary = last_map |> Map.get("type_parameters")

        parameter_map = Map.new
        |> Map.put("name", String.trim(row[:Parameter]))
        |> Map.put("type", String.trim(row[:Type]))

        type_map = Map.put(last_map, "type_parameters", parameter_ary ++ [parameter_map])

        acc ++ [type_map]
      else
        parameter_map = Map.new
        |> Map.put("name", String.trim(row[:Parameter]))
        |> Map.put("type", String.trim(row[:Type]))

        type_map = Map.new
        |> Map.put("type_name", String.trim(row[:Name]))
        |> Map.put("type_description", String.trim(row[:Description]))
        |> Map.put("type_parameters",  [parameter_map])

        acc ++ [type_map]
      end
    end)
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

end
