defmodule TdDqWeb.FunctionView do
  use TdDqWeb, :view

  def render("function.json", %{function: %{args: args} = function}) do
    args = Enum.map(args, &render_arg/1)

    function
    |> Map.take([:id, :name, :return_type, :group, :scope])
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
    |> Map.put(:args, args)
  end

  defp render_arg(%{type: type, values: values}) when is_list(values),
    do: %{type: type, values: values}

  defp render_arg(%{type: type, values: nil}), do: %{type: type}
end
