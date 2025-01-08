defmodule TdDqWeb.FunctionController do
  use TdDqWeb, :controller

  alias TdDq.Functions

  action_fallback(TdDqWeb.FallbackController)

  def index(conn, _params) do
    claims = conn.assigns[:current_resource]

    with :ok <- Bodyguard.permit(Functions, :query, claims) do
      functions = Functions.list_functions()

      render(conn, "index.json", functions: functions)
    end
  end

  def create(conn, params) do
    claims = conn.assigns[:current_resource]

    with :ok <- Bodyguard.permit(Functions, :create, claims),
         {:ok, function} <- Functions.create_function(params) do
      render(conn, "show.json", function: function)
    end
  end

  def delete(conn, %{"id" => id}) do
    claims = conn.assigns[:current_resource]

    with :ok <- Bodyguard.permit(Functions, :delete, claims),
         function <- Functions.get_function!(id),
         {:ok, _} <- Functions.delete_function(function) do
      send_resp(conn, :no_content, "")
    end
  end
end
