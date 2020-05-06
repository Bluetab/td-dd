defmodule TdDdWeb.UnitView do
  use TdDdWeb, :view

  def render("index.json", %{units: units}) do
    %{data: render_many(units, __MODULE__, "unit.json")}
  end

  def render("show.json", %{unit: unit}) do
    %{data: render_one(unit, __MODULE__, "unit.json")}
  end

  def render("unit.json", %{unit: %{status: status} = unit}) do
    json =
      unit
      |> Map.take([:name, :inserted_at, :updated_at, :deleted_at])
      |> Enum.reject(fn {_, value} -> is_nil(value) end)
      |> Map.new()

    case render_one(status, TdDdWeb.UnitEventView, "event.json", as: :event) do
      nil -> json
      status -> Map.put(json, :status, status)
    end
  end
end
