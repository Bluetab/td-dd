defmodule TdDdWeb.UserView do
  use TdDdWeb, :view

  def render("embedded.json", %{user: user}) do
    Map.take(user, [:id, :user_name, :full_name])
  end
end
