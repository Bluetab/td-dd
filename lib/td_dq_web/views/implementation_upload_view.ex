defmodule TdDqWeb.ImplementationUploadView do
  use TdDqWeb, :view

  def render("create.json", %{ids: ids, errors: errors}) do
    %{data: %{ids: Enum.reverse(ids), errors: Enum.reverse(errors)}}
  end

  def render("error.json", %{error: error}) do
    %{error: error}
  end
end
