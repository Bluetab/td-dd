defmodule TruedatWeb.ErrorView do
  use TruedatWeb, :view

  def render("404.json", _assigns) do
    %{errors: %{detail: "Not found"}}
  end

  def render("403.json", _assigns) do
    %{errors: %{detail: "Forbidden"}}
  end

  def render("500.json", _assigns) do
    %{errors: %{detail: "Internal server error"}}
  end

  def template_not_found(template, _assigns) do
    %{errors: %{detail: Phoenix.Controller.status_message_from_template(template)}}
  end
end
