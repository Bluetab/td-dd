defmodule TdDqWeb.FunctionController do
  use TdDqWeb, :controller

  alias TdDq.Functions
  alias TdDqWeb.SwaggerDefinitions

  action_fallback(TdDqWeb.FallbackController)

  def swagger_definitions do
    SwaggerDefinitions.function_swagger_definitions()
  end

  swagger_path :index do
    description("Get functions")
    produces("application/json")

    response(200, "OK", Schema.ref(:FunctionsResponse))
    response(422, "Client Error")
  end

  def index(conn, _params) do
    claims = conn.assigns[:current_resource]

    with :ok <- Bodyguard.permit(Functions, :query, claims) do
      functions = Functions.list_functions()

      render(conn, "index.json", functions: functions)
    end
  end

  swagger_path :create do
    description("Create a function")
    produces("application/json")

    parameters do
      configuration(:body, Schema.ref(:CreateFunction), "Function definition")
    end

    response(200, "OK", Schema.ref(:FunctionResponse))
    response(403, "Forbidden")
    response(422, "Client Error")
  end

  def create(conn, params) do
    claims = conn.assigns[:current_resource]

    with :ok <- Bodyguard.permit(Functions, :create, claims),
         {:ok, function} <- Functions.create_function(params) do
      render(conn, "show.json", function: function)
    end
  end

  swagger_path :delete do
    description("Deletes a function")

    parameters do
      id(:path, :string, "Function id", required: true)
    end

    response(204, "No Content")
    response(403, "Forbidden")
    response(422, "Client Error")
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
