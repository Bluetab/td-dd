defmodule TdDdWeb.ReferenceDataController do
  use TdDdWeb, :controller

  alias Plug.Upload
  alias TdDd.ReferenceData
  alias TdDd.ReferenceData.Dataset
  alias TdDd.ReferenceData.Policy

  require Logger

  action_fallback(TdDdWeb.FallbackController)

  def index(conn, _params) do
    claims = conn.assigns[:current_resource]
    permitted_domain_ids = Policy.view_permitted_domain_ids(claims)

    with :ok <- Bodyguard.permit(ReferenceData, :list, claims),
         datasets <- ReferenceData.list(%{domain_ids: permitted_domain_ids}) do
      render(conn, "index.json", datasets: datasets)
    end
  end

  def show(conn, %{"id" => id}) do
    claims = conn.assigns[:current_resource]

    with :ok <- Bodyguard.permit(ReferenceData, :view, claims),
         %{} = dataset <- ReferenceData.get!(id),
         :ok <- Bodyguard.permit(ReferenceData, :show, claims, dataset) do
      render(conn, "show.json", dataset: dataset)
    end
  end

  def create(conn, %{"dataset" => %Upload{path: path}, "name" => name, "domain_ids" => domain_ids}) do
    claims = conn.assigns[:current_resource]

    with :ok <- Bodyguard.permit(ReferenceData, :create, claims),
         {:ok, %{} = dataset} <-
           ReferenceData.create(%{name: name, path: path, domain_ids: domain_ids}) do
      conn
      |> put_status(:created)
      |> render("show.json", dataset: dataset)
    end
  end

  def update(conn, %{
        "id" => id,
        "name" => name,
        "dataset" => %Upload{path: path},
        "domain_ids" => domain_ids
      }) do
    claims = conn.assigns[:current_resource]

    with :ok <- Bodyguard.permit(ReferenceData, :update, claims),
         %Dataset{} = dataset <- ReferenceData.get!(id),
         :ok <- Bodyguard.permit(ReferenceData, :update, claims, dataset),
         {:ok, %{} = dataset} <-
           ReferenceData.update(dataset, %{name: name, path: path, domain_ids: domain_ids}) do
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
