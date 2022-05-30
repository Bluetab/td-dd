defmodule TdDdWeb.ProfileView do
  use TdDdWeb, :view

  def render("index.json", %{profiles: profiles}) do
    %{data: render_many(profiles, __MODULE__, "profile.json")}
  end

  def render("show.json", %{profile: profile}) do
    %{data: render_one(profile, __MODULE__, "profile.json")}
  end

  def render("profile.json", %{profile: profile}) do
    %{
      id: profile.id,
      data_structure_id: profile.data_structure_id,
      value: profile.value,
      updated_at: profile.updated_at
    }
  end
end
