defmodule TdDdWeb.ErrorViewTest do
  use TdDdWeb.ConnCase, async: true

  # Bring render/3 and render_to_string/3 for testing custom views
  import Phoenix.View

  test "renders 403.json" do
    assert render(TdDdWeb.ErrorView, "403.json", []) ==
           %{errors: %{detail: "Invalid authorization"}}
  end

  test "renders 404.json" do
    assert render(TdDdWeb.ErrorView, "404.json", []) ==
           %{errors: %{detail: "Not found"}}
  end

  test "render 500.json" do
    assert render(TdDdWeb.ErrorView, "500.json", []) ==
           %{errors: %{detail: "Internal server error"}}
  end

  test "render any other" do
    assert render(TdDdWeb.ErrorView, "505.json", []) ==
           %{errors: %{detail: "Internal server error"}}
  end
end
