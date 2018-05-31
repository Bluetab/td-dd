defmodule TdDqWeb.QualityControl do
  @moduledoc false

  alias Poison, as: JSON
  import TdDqWeb.Router.Helpers
  import TdDqWeb.Authentication, only: :functions

  @endpoint TdDqWeb.Endpoint

  @test_to_api_create_alias %{"Field" => "field", "Business Concept ID" => "business_concept_id",
    "Name" => "name", "Description" => "description", "Weight" => "weight",
    "Priority" => "priority", "Population" => "population", "Goal" => "goal", "Minimum" => "minimum",
    "Type" => "type", "Type Params" => "type_params"
  }

  @test_to_api_get_alias %{"Status" => "status", "Last User" => "updated_by", "Version" => "version", "Last Modification" => "inserted_at"}

  @quality_control_integer_fields ["weight", "goal", "minimum"]

  def quality_control_create(token, quality_control_params) do
    headers = get_header(token)
    body = %{quality_control: quality_control_params} |> JSON.encode!
    %HTTPoison.Response{status_code: status_code, body: resp} =
      HTTPoison.post!(quality_control_url(@endpoint, :create), body, headers, [])
    {:ok, status_code, resp |> JSON.decode!}
  end

  def quality_control_list(token) do
    headers = get_header(token)
    %HTTPoison.Response{status_code: status_code, body: resp} =
      HTTPoison.get!(quality_control_url(@endpoint, :index), headers, [])
    {:ok, status_code, resp |> JSON.decode!}
  end

  def create_new_quality_control(token, table) do
    attrs = table
    |> field_value_to_api_attrs(@test_to_api_create_alias)
    attrs = attrs
    |> cast_to_int_attrs(@quality_control_integer_fields)
    |> cast_to_map_attrs
    quality_control_create(token, attrs)
  end

  def find_quality_control(token, search_params) do
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

  def quality_control_test_fields_to_api_create_and_get_alias(table) do
    table |> field_value_to_api_attrs(Map.merge(@test_to_api_create_alias, @test_to_api_get_alias))
  end

  def cast_quality_control_integer_fields_plus_version(table) do
    table |> cast_to_int_attrs(@quality_control_integer_fields ++ ["version"])
  end

  def cast_to_map_attrs(m) do
    m
    |> Enum.map(fn({k, v}) ->
      if is_binary(v) do
        to_map = case String.split(v, "%-") do
          [_, params] -> {:ok, String.split(params, ", ")}
          _ -> nil
        end
        case to_map do
          {:ok, param_list} ->
            {k, Enum.reduce(param_list, %{}, fn(x, acc) ->
                  [key, value] = String.split(x, ": ")
                  Map.put(acc, key, value)
                end)}
          nil ->
            {k, v}
        end
      else
        {k, v}
      end
      end)
    |> Enum.into(%{})
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

  defp field_value_to_api_attrs(table, key_alias_map) do
    table
    |> Enum.reduce(%{}, fn(x, acc) -> Map.put(acc, Map.get(key_alias_map, x."Field", x."Field"), x."Value") end)
  end
end
