defmodule TdDdWeb.ProfileEventView do
  use TdDdWeb, :view

  def render("show.json", %{profile_event: event}) do
    %{data: render_one(event, __MODULE__, "profile_event.json")}
  end

  def render("profile_event.json", %{profile_event: event}) do
    Map.take(event, [:id, :inserted_at, :profile_execution_id, :type, :message])
  end
end
