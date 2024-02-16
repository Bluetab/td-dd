defmodule TdDdWeb.ReferenceDataDownloadController do
  use TdDdWeb, :controller

  alias TdDd.ReferenceData

  action_fallback(TdDdWeb.FallbackController)

  def show(conn, %{"reference_data_id" => id}) do
    claims = conn.assigns[:current_resource]

    with :ok <- Bodyguard.permit(ReferenceData, :download, claims),
         %{} = dataset <- ReferenceData.get!(id),
         :ok <- Bodyguard.permit(ReferenceData, :download, claims, dataset) do
      conn
      |> put_resp_content_type("text/csv", "utf-8")
      |> put_resp_header("content-disposition", "attachment; filename=\"ref_data_#{id}.csv\"")
      |> send_resp(:ok, ReferenceData.to_csv(dataset))
    end
  end
end
