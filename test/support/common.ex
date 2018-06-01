defmodule TdDqWeb.SupportCommon do
  @moduledoc false

  alias Poison, as: JSON

  def field_value_to_api_attrs(table, key_alias_map) do
    table
    |> Enum.reduce(%{}, fn(x, acc) ->
      model_key = Map.get(key_alias_map, x."Field", x."Field")
      value =
        case String.split(x."Value", "%-") do
          [_, params] -> JSON.decode!(params)
          _ -> x."Value"
        end
      Map.put(acc, model_key, value)
    end)
  end
end
