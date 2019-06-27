defmodule TdDqWeb.RuleType do
  @moduledoc false

  import TdDqWeb.Router.Helpers
  import TdDqWeb.Authentication, only: :functions

  alias Jason, as: JSON

  @endpoint TdDqWeb.Endpoint

  def rule_type_create(token, %{"name" => name, "params" => params}) do
    params
    |> table_to_entity_attrs(name)
    |> (&do_rule_type_create(token, &1)).()
  end

  defp do_rule_type_create(token, qrt_params) do
    headers = get_header(token)
    body = %{rule_type: qrt_params} |> JSON.encode!()

    %HTTPoison.Response{status_code: status_code, body: resp} =
      HTTPoison.post!(rule_type_url(@endpoint, :create), body, headers, [])

    {:ok, status_code, resp |> JSON.decode!()}
  end

  def rule_type_find(token, search_params) do
    {:ok, _status_code, json_resp} = rule_type_list(token)

    Enum.find(json_resp["data"], fn rule_type ->
      Enum.all?(search_params, fn {k, v} ->
        string_key = Atom.to_string(k)
        rule_type[string_key] == v
      end)
    end)
  end

  defp rule_type_list(token) do
    headers = get_header(token)

    %HTTPoison.Response{status_code: status_code, body: resp} =
      HTTPoison.get!(rule_type_url(@endpoint, :index), headers, [])

    {:ok, status_code, resp |> JSON.decode!()}
  end

  defp table_to_entity_attrs(table, br_name) do
    params =
      table
      |> Enum.reduce(%{}, fn x, acc ->
        new = JSON.decode!(x."Params")
        Map.merge(acc, new)
      end)

    %{}
    |> Map.put("params", params)
    |> Map.put("name", br_name)
  end
end
