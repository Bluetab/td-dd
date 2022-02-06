defmodule TdDdWeb.AccessController do
  use TdDdWeb, :controller
  use PhoenixSwagger

  alias TdDd.Access.BulkLoad

  import Canada, only: [can?: 2]

  action_fallback(TdDdWeb.FallbackController)

  def create(conn, %{"accesses" => accesses} = _params) do
    with claims <- conn.assigns[:current_resource],
         {:can, true} <- {:can, can?(claims, create(Access))},
         {inserted_count, invalid_changesets, inexistent_external_ids} <-
           BulkLoad.bulk_load(accesses) do
      render(conn, "create.json",
        inserted_count: inserted_count,
        invalid_changesets: invalid_changesets,
        inexistent_external_ids: inexistent_external_ids
      )
    else
      {:error, {:can, false}} -> {:can, false}
      error -> error
    end
  end
end
