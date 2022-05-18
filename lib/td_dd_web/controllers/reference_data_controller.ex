defmodule TdDdWeb.ReferenceDataController do
  use TdDdWeb, :controller

  import Canada, only: [can?: 2]

  alias Plug.Upload
  alias TdDd.ReferenceData
  alias TdDd.ReferenceData.Dataset

  require Logger

  action_fallback(TdDdWeb.FallbackController)

  def index(conn, _params) do
    claims = conn.assigns[:current_resource]

    with {:can, true} <- {:can, can?(claims, list(Dataset))},
         datasets <- ReferenceData.list() do
      render(conn, "index.json", datasets: datasets)
    end
  end

  def show(conn, %{"id" => id}) do
    claims = conn.assigns[:current_resource]

    with {:can, true} <- {:can, can?(claims, show(Dataset))},
         %{} = dataset <- ReferenceData.get!(id),
         {:can, true} <- {:can, can?(claims, show(dataset))} do
      render(conn, "show.json", dataset: dataset)
    end
  end

  def create(conn, %{"dataset" => %Upload{path: path}, "name" => name}) do
    claims = conn.assigns[:current_resource]

    with {:can, true} <- {:can, can?(claims, create(Dataset))},
         {:ok, %{} = dataset} <- ReferenceData.create(%{name: name, path: path}) do
      conn
      |> put_status(:created)
      |> render("show.json", dataset: dataset)
    end
  end

  def update(conn, %{"id" => id, "name" => name, "dataset" => %Upload{path: path}}) do
    claims = conn.assigns[:current_resource]

    with {:can, true} <- {:can, can?(claims, update(Dataset))},
         %Dataset{} = dataset <- ReferenceData.get!(id),
         {:can, true} <- {:can, can?(claims, update(dataset))},
         {:ok, %{} = dataset} <- ReferenceData.update(dataset, %{name: name, path: path}) do
      render(conn, "show.json", dataset: dataset)
    end
  end

  def delete(conn, %{"id" => id}) do
    claims = conn.assigns[:current_resource]

    with {:can, true} <- {:can, can?(claims, delete(Dataset))},
         %{} = dataset <- ReferenceData.get!(id),
         {:can, true} <- {:can, can?(claims, delete(dataset))},
         {:ok, %{} = _dataset} <- ReferenceData.delete(dataset) do
      send_resp(conn, :no_content, "")
    end
  end
end
