defmodule TdDdWeb.ReferenceDataController do
  use TdDdWeb, :controller

  alias Plug.Upload
  alias TdDd.ReferenceData
  alias TdDd.ReferenceData.Dataset

  require Logger

  action_fallback(TdDdWeb.FallbackController)

  def index(conn, _params) do
    claims = conn.assigns[:current_resource]

    with :ok <- Bodyguard.permit(ReferenceData, :list, claims),
         datasets <- ReferenceData.list() do
      render(conn, "index.json", datasets: datasets)
    end
  end

  def show(conn, %{"id" => id}) do
    claims = conn.assigns[:current_resource]

    with :ok <- Bodyguard.permit(ReferenceData, :view, claims),
         %{} = dataset <- ReferenceData.get!(id),
         :ok <- Bodyguard.permit(ReferenceData, :view, claims, dataset) do
      render(conn, "show.json", dataset: dataset)
    end
  end

  def create(conn, %{"dataset" => %Upload{path: path}, "name" => name}) do
    claims = conn.assigns[:current_resource]

    with :ok <- Bodyguard.permit(ReferenceData, :create, claims),
         {:ok, %{} = dataset} <- ReferenceData.create(%{name: name, path: path}) do
      conn
      |> put_status(:created)
      |> render("show.json", dataset: dataset)
    end
  end

  def update(conn, %{"id" => id, "name" => name, "dataset" => %Upload{path: path}}) do
    claims = conn.assigns[:current_resource]

    with :ok <- Bodyguard.permit(ReferenceData, :update, claims),
         %Dataset{} = dataset <- ReferenceData.get!(id),
         :ok <- Bodyguard.permit(ReferenceData, :update, claims, dataset),
         {:ok, %{} = dataset} <- ReferenceData.update(dataset, %{name: name, path: path}) do
      render(conn, "show.json", dataset: dataset)
    end
  end

  def delete(conn, %{"id" => id}) do
    claims = conn.assigns[:current_resource]

    with :ok <- Bodyguard.permit(ReferenceData, :delete, claims),
         %{} = dataset <- ReferenceData.get!(id),
         :ok <- Bodyguard.permit(ReferenceData, :delete, claims, dataset),
         {:ok, %{} = _dataset} <- ReferenceData.delete(dataset) do
      send_resp(conn, :no_content, "")
    end
  end
end
