defmodule TdDqWeb.QualityRuleType do
  @moduledoc false

  alias Poison, as: JSON
  import TdDqWeb.Router.Helpers
  import TdDqWeb.Authentication, only: :functions

  @endpoint TdDqWeb.Endpoint

  @test_quality_rule_type_create_alias %{"Name" => "name", "Type" => "type"}

  def create_new_quality_rule_type(token, %{"name" => name, "params" => params}) do
    params
     |> field_value_to_entity_attrs(@test_quality_rule_type_create_alias, name)
     |> (&quality_rule_type_create(token, &1)).()
  end

  def quality_rule_type_create(token, qrt_params) do
    headers = get_header(token)
    body = %{quality_rule_type: qrt_params} |> JSON.encode!
    %HTTPoison.Response{status_code: status_code, body: resp} =
      HTTPoison.post!(quality_rule_type_url(@endpoint, :create), body, headers, [])
    {:ok, status_code, resp |> JSON.decode!}
  end

  def find_quality_rule_type(token, search_params) do
    {:ok, _status_code, json_resp} = quality_rule_type_list(token)
    Enum.find(json_resp["data"], fn(quality_rule_type) ->
      Enum.all?(search_params, fn({k, v}) ->
        string_key = Atom.to_string(k)
        quality_rule_type[string_key] == v
      end
      )
    end
    )
  end

  defp quality_rule_type_list(token) do
    headers = get_header(token)
    %HTTPoison.Response{status_code: status_code, body: resp} =
      HTTPoison.get!(quality_rule_type_url(@endpoint, :index), headers, [])
    {:ok, status_code, resp |> JSON.decode!}
  end

  defp field_value_to_entity_attrs(table, key_alias_map, br_name) do
    params = Enum.group_by(table, &(&1."Params"))
    type_params =
      params["Type Params"]
      |> Enum.map(&(Map.delete(&1, :Params)))
      |> Enum.map(&(for {k, v} <- &1 do {key_alias_map["#{k}"], v} end |> Map.new))
    system_params =
      params["System Params"]
      |> Enum.map(&(Map.delete(&1, :Params)))
      |> Enum.map(&(for {k, v} <- &1 do {key_alias_map["#{k}"], v} end |> Map.new))
    %{}
    |> Map.put("name", br_name)
    |> Map.put("params", %{} |> Map.put("type_params", type_params) |> Map.put("system_params", system_params))
  end
end
