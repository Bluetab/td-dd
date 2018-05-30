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

  defp field_value_to_entity_attrs(table, key_alias_map, br_name) do
    attrs = table
    |> Enum.map(fn(x) ->
      %{key_alias_map["Name"] => x."Name", key_alias_map["Type"] => x."Type"}
    end)
    %{}
    |> Map.put("name", br_name)
    |> Map.put("params", %{} |> Map.put("type_params", attrs))
  end
end
