defmodule TdDdWeb.AccessController do
  use TdDdWeb, :controller
  use PhoenixSwagger

  alias TdDd.Access.BulkLoad

  import Canada, only: [can?: 2]

  action_fallback(TdDdWeb.FallbackController)



  def create(conn, %{"accesses" => accesses} = _params) do
    with _claims <- conn.assigns[:current_resource] |> IO.inspect(label: "CLAIMS"),
         result = {inserted_count, invalid_changesets, inexistent_external_ids} <- BulkLoad.bulk_load(accesses) |> IO.inspect(label: "BULK_LOAD") do
      IO.inspect(label: "ACCESSES")
      render(conn, "create.json", inserted_count: inserted_count, invalid_changesets: invalid_changesets, inexistent_external_ids: inexistent_external_ids)
    else
      {:error, {:can, false}} -> {:can, false}
      error -> error
    end
  end

end
