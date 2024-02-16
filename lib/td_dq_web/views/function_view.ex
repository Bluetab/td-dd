defmodule TdDqWeb.FunctionView do
  use TdDqWeb, :view

  def render("index.json", %{functions: functions}) do
    %{data: render_many(functions, __MODULE__, "function.json")}
  end

  def render("show.json", %{function: function}) do
    %{data: render_one(function, __MODULE__, "function.json")}
  end

  def render("function.json", %{function: %{args: args} = function}) do
    args = Enum.map(args, &render_arg/1)

    function
    |> Map.take([:id, :name, :return_type, :group, :scope])
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
    |> Map.put(:args, args)
  end

  defp render_arg(%{} = arg) do
    arg
    |> Map.take([:name, :type, :values])
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end
end
