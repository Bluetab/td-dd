defmodule TdDdWeb.UnitEventView do
  use TdDdWeb, :view

  def render("index.json", %{events: events}) do
    events = Enum.sort_by(events, & &1.inserted_at, {:desc, DateTime})
    %{data: render_many(events, __MODULE__, "event.json", as: :event)}
  end

  def render("event.json", %{event: %{inserted_at: timestamp} = event}) do
    event
    |> Map.take([:event, :info])
    |> Enum.reject(fn {_, value} -> is_nil(value) end)
    |> Map.new()
    |> Map.put(:timestamp, timestamp)
  end
end
