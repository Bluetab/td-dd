defmodule TdDdWeb.AccessController do
  use TdDdWeb, :controller

  alias TdDd.Access.BulkLoad

  action_fallback(TdDdWeb.FallbackController)

  def create(conn, %{"accesses" => accesses} = params) do
    claims = conn.assigns[:current_resource]

    with :ok <- Bodyguard.permit(BulkLoad, :create, claims, params),
         {inserted_count, invalid_changesets, inexistent_external_ids} <-
           BulkLoad.bulk_load(accesses) do
      render(conn, "create.json",
        inserted_count: inserted_count,
        invalid_changesets: invalid_changesets,
        inexistent_external_ids: inexistent_external_ids
      )
    end
  end
end
