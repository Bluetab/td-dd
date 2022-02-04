defmodule TdDdWeb.AccessView do
  use TdDdWeb, :view

  def render("create.json", %{
        inserted_count: inserted_count,
        invalid_changesets: invalid_changesets,
        inexistent_external_ids: inexistent_external_ids
      }) do
    %{
      data: %{
        inserted_count: inserted_count,
        inexistent_external_ids: inexistent_external_ids,
        invalid_changesets: render_many(invalid_changesets, TdDdWeb.ChangesetView, "error.json")
      }
    }
  end
end
