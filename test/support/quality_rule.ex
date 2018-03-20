defmodule TdDqWeb.QualityRule do
  @moduledoc false

  alias Poison, as: JSON
  import TdDqWeb.Router.Helpers
  import TdDqWeb.Authentication, only: :functions

  @endpoint TdDqWeb.Endpoint

  @test_fields_to_api %{
    "Type" => "type", "System" => "system", "Name" => "name",
    "Description" => "description", "Parameters" => "parameters"
  }

  def create_empty_quality_rule_type(quality_rule_type) do
    json_schema = [%{"type_name": quality_rule_type, "type_parameters": nil}] |> JSON.encode!
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
    table
    |> Enum.reduce(%{}, fn(x, acc) -> Map.put(acc, Map.get(@test_fields_to_api, x."Field", x."Field"), x."Value") end)
    |> Map.split(Map.values(@test_fields_to_api))
    |> fn({f, v}) -> Map.put(f, "parameters", v) end.()
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
