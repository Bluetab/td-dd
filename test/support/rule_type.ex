defmodule TdDqWeb.RuleType do
  @moduledoc false

  alias Poison, as: JSON
  import TdDqWeb.Router.Helpers
  import TdDqWeb.Authentication, only: :functions

  @endpoint TdDqWeb.Endpoint

  def create_new_rule_implementation_type(token, %{"name" => name, "params" => params}) do
    params
     |> table_to_entity_attrs(name)
     |> (&quality_rule_type_create(token, &1)).()
  end

  def quality_rule_type_create(token, qrt_params) do
    headers = get_header(token)
    body = %{quality_rule_type: qrt_params} |> JSON.encode!
    %HTTPoison.Response{status_code: status_code, body: resp} =
      HTTPoison.post!(rule_type_url(@endpoint, :create), body, headers, [])
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
      HTTPoison.get!(rule_type_url(@endpoint, :index), headers, [])
    {:ok, status_code, resp |> JSON.decode!}
  end

  defp table_to_entity_attrs(table, br_name) do
    params =
    table
    |> Enum.reduce(%{}, fn(x, acc) ->
        new = JSON.decode!(x."Params")
        Map.merge(acc, new)
    end)

    %{}
    |> Map.put("params", params)
    |> Map.put("name", br_name)
  end
end
