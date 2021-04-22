defmodule TdCxWeb.ConfigurationSignerView do
  use TdCxWeb, :view

  def render("show.json", %{token: token}) do
    %{token: token}
  end
end
