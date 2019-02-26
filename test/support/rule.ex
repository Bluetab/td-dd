defmodule TdDqWeb.Rule do
  @moduledoc false

  alias Poison, as: JSON
  import TdDqWeb.Router.Helpers
  import TdDqWeb.Authentication, only: :functions
  import TdDqWeb.SupportCommon, only: :functions

  @endpoint TdDqWeb.Endpoint

  @test_to_api_create_alias %{"Field" => "field",
                              "Business Concept ID" => "business_concept_id",
                              "Name" => "name",
                              "Description" => "description",
                              "Weight" => "weight",
                              "Priority" => "priority",
                              "Population" => "population",
                              "Goal" => "goal",
                              "Minimum" => "minimum",
                              "Type" => "rule_type_id",
                              "Type Params" => "type_params"}

  @test_to_api_get_alias %{"Active" => "active",
                           "Last User" => "updated_by",
                           "Version" => "version",
                           "Last Modification" => "inserted_at"}

  @rule_integer_fields ["rule_type_id",
                        "weight",
                        "goal",
                        "minimum"]

  def active_to_boolean("true"), do: true
  def active_to_boolean("false"), do: false
  def active_to_boolean(_), do: false

  def rule_list(token) do
    headers = get_header(token)
    %HTTPoison.Response{status_code: status_code, body: resp} =
      HTTPoison.get!(rule_url(@endpoint, :index), headers, [])
    {:ok, status_code, resp |> JSON.decode!}
  end

  def rule_create(token, table) do
    attrs = table
    |> field_value_to_api_attrs(@test_to_api_create_alias)
    attrs = attrs
    |> cast_to_int_attrs(@rule_integer_fields)
    do_rule_create(token, attrs)
  end

  def do_rule_create(token, rule_params) do
    headers = get_header(token)
    body = %{rule: rule_params} |> JSON.encode!
    %HTTPoison.Response{status_code: status_code, body: resp} =
      HTTPoison.post!(rule_url(@endpoint, :create), body, headers, [])
    {:ok, status_code, resp |> JSON.decode!}
  end

  def find_rule(token, search_params) do
    {:ok, _status_code, json_resp} = rule_list(token)
    Enum.find(json_resp["data"], fn(rule) ->
      Enum.all?(search_params, fn({k, v}) ->
        string_key = Atom.to_string(k)
        rule[string_key] == v
      end
      )
    end
    )
  end

  def rule_test_fields_to_api_create_and_get_alias(table) do
    table |> field_value_to_api_attrs(Map.merge(@test_to_api_create_alias, @test_to_api_get_alias))
  end

  def cast_rule_integer_fields_plus_version(table) do
    table |> cast_to_int_attrs(@rule_integer_fields ++ ["version"])
  end

  defp cast_to_int_attrs(m, keys) do
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
end
