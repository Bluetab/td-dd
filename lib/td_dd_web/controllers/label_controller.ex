defmodule TdDdWeb.LabelController do
  use TdDdWeb, :controller

  alias TdDd.DataStructures.DataStructureLinks
  alias TdDd.DataStructures.Label

  action_fallback(TdDdWeb.FallbackController)

  def index(conn, _params) do
    claims = conn.assigns[:current_resource]

    with :ok <- Bodyguard.permit(DataStructureLinks, :query_labels, claims),
         labels <- DataStructureLinks.list_labels() do
      render(conn, "index.json", labels: labels)
    end
  end

  def create(conn, %{"name" => _name} = params) do
    claims = conn.assigns[:current_resource]

    with :ok <- Bodyguard.permit(DataStructureLinks, :create_label, claims, %{}),
         {:ok, %Label{} = label} <- DataStructureLinks.create_label(params) do
      conn
      |> put_status(:created)
      |> render("show.json", label: label)
    end
  end

  def delete(conn, %{"id" => _id} = params) do
    claims = conn.assigns[:current_resource]

    with %Label{} = label <- DataStructureLinks.get_label_by(params),
         :ok <- Bodyguard.permit(DataStructureLinks, :delete_label, claims, Label),
         {:ok, %Label{}} <- DataStructureLinks.delete_label(label) do
      send_resp(conn, :no_content, "")
    end
  end

  def delete_by_name(conn, %{"name" => _name} = params) do
    claims = conn.assigns[:current_resource]

    with %Label{} = label <- DataStructureLinks.get_label_by(params),
         :ok <- Bodyguard.permit(DataStructureLinks, :delete_label, claims, Label),
         {:ok, %Label{}} <- DataStructureLinks.delete_label(label) do
      send_resp(conn, :no_content, "")
    end
  end
end
