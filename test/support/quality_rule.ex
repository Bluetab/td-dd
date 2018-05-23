defmodule TdDqWeb.QualityRule do
  @moduledoc false

  alias Poison, as: JSON
  import TdDqWeb.Router.Helpers
  import TdDqWeb.Authentication, only: :functions

  @endpoint TdDqWeb.Endpoint

  @test_fields_to_api %{
    "Type" => "type", "System" => "system", "Name" => "name",
    "Description" => "description", "Parameters" => "type_params", "Tag" => "tag"
  }

  def create_empty_quality_rule_types(quality_rule_type) do
    write_quality_rule_types([%{"type_name": quality_rule_type, "type_parameters": [], "tag": []}])
  end

  def create_quality_rule_types_from_table(table) do
    quality_rule_types = get_quality_control_types_from_table(table)
    write_quality_rule_types(quality_rule_types)
  end

  def get_quality_control_types_from_table(table) do
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
        |> Map.put("type_parameters",  [parameter_map])

        acc ++ [type_map]
      end
    end)
  end

  defp write_quality_rule_types(quality_rule_types) do
    json_schema = quality_rule_types |> JSON.encode!
    file_name = Application.get_env(:td_dq, :qr_types_file)
    file_path = Path.join(:code.priv_dir(:td_dq), file_name)
    File.write!(file_path, json_schema, [:write, :utf8])
  end

  def create_new_quality_rule(token, table, quality_control_id) do
    attrs = table
    |> quality_rule_test_fields_to_api
    |> Map.put("quality_control_id", quality_control_id)
    quality_rule_create(token, attrs)
  end

  def quality_rule_test_fields_to_api(table) do
    table = table
    |> Enum.reduce(%{}, fn(x, acc) -> Map.put(acc, Map.get(@test_fields_to_api, x."Field", x."Field"), x."Value") end)
    |> Map.split(Map.values(@test_fields_to_api))
    |> fn({f, v}) -> Map.put(f, "type_params", v) end.()
    |> Map.split(Map.values(@test_fields_to_api))
    |> fn({f, v}) -> Map.put_new(f, "tag", v) end.()

    tag = Map.get(table, "tag")
    if is_map(tag), do: table, else: Map.put(table, "tag", tag |> JSON.decode!)
  end

  def quality_rule_create(token, quality_rule_params) do
    headers = get_header(token)
    body = %{quality_rule: quality_rule_params} |> JSON.encode!
    %HTTPoison.Response{status_code: status_code, body: resp} =
     HTTPoison.post!(quality_rule_url(@endpoint, :create), body, headers, [])
    {:ok, status_code, resp |> JSON.decode!}
  end

  def quality_rule_show(token, id) do
    headers = get_header(token)
    %HTTPoison.Response{status_code: status_code, body: resp} =
      HTTPoison.get!(quality_rule_url(@endpoint, :show, id), headers, [])
    {:ok, status_code, resp |> JSON.decode!}
  end

  def quality_rule_list(token) do
    headers = get_header(token)
    %HTTPoison.Response{status_code: status_code, body: resp} =
      HTTPoison.get!(quality_rule_url(@endpoint, :index), headers, [])
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

end
