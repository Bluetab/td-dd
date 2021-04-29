defmodule TdDdWeb.ProfileView do
  use TdDdWeb, :view

  def render("show.json", %{profile: profile}) do
    %{data: render_one(profile, ProfileView, "profile.json")}
  end

  def render("profile.json", %{profile: profile}) do
    %{id: profile.id, data_structure_id: profile.data_structure_id, value: profile.value}
  end
end
