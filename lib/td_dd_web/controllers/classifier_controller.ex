defmodule TdDdWeb.ClassifierController do
  use TdDdWeb, :controller

  alias TdDd.Classifiers
  alias TdDd.Systems

  plug :get_system

  action_fallback(TdDdWeb.FallbackController)

  def action(conn, _) do
    args = [conn, conn.params, conn.assigns.system]
    apply(__MODULE__, action_name(conn), args)
  end

  def index(conn, _params, system) do
    with claims <- conn.assigns[:current_resource],
         :ok <- Bodyguard.permit(Systems, :view, claims, system) do
      render(conn, "index.json", classifiers: system.classifiers)
    end
  end

  def create(conn, %{"classifier" => params}, system) do
    with claims <- conn.assigns[:current_resource],
         :ok <- Bodyguard.permit(Systems, :classify, claims, system),
         {:ok, %{classifier: classifier}} <- Classifiers.create_classifier(system, params) do
      conn
      |> put_status(:created)
      |> render("show.json", classifier: classifier)
    end
  end

  def delete(conn, %{"id" => id}, system) do
    with claims <- conn.assigns[:current_resource],
         classifier <- Classifiers.get_classifier!(system, id),
         :ok <- Bodyguard.permit(Systems, :delete, claims, classifier),
         {:ok, _multi_result} <- Classifiers.delete_classifier(classifier) do
      send_resp(conn, :no_content, "")
    end
  end

  def get_system(conn, _opts) do
    system =
      Systems.get_system!(conn.params["system_id"], preload: [classifiers: [:filters, :rules]])

    assign(conn, :system, system)
  end
end
