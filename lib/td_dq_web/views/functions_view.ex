defmodule TdDqWeb.FunctionsView do
  use TdDqWeb, :view

  def render("show.json", %{functions: functions}) do
    %{data: render_many(functions, TdDqWeb.FunctionView, "function.json")}
  end
end
