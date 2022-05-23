defmodule TdDdWeb.ReferenceDataDownloadController do
  use TdDdWeb, :controller

  import Canada, only: [can?: 2]

  alias TdDd.ReferenceData
  alias TdDd.ReferenceData.Dataset

  action_fallback(TdDdWeb.FallbackController)

  def show(conn, %{"reference_data_id" => id}) do
    claims = conn.assigns[:current_resource]

    with {:can, true} <- {:can, can?(claims, download(Dataset))},
         %{} = dataset <- ReferenceData.get!(id),
         {:can, true} <- {:can, can?(claims, download(dataset))} do
      conn
      |> put_resp_content_type("text/csv", "utf-8")
      |> put_resp_header("content-disposition", "attachment; filename=\"ref_data_#{id}.csv\"")
      |> send_resp(:ok, ReferenceData.to_csv(dataset))
    end
  end
end
