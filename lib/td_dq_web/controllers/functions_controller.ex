defmodule TdDqWeb.FunctionsController do
  use TdDqWeb, :controller

  alias TdDq.Functions
  alias TdDqWeb.SwaggerDefinitions

  action_fallback(TdDqWeb.FallbackController)

  def swagger_definitions do
    SwaggerDefinitions.function_swagger_definitions()
  end

  swagger_path :update do
    description("Replace functions")
    produces("application/json")

    parameters do
      configuration(:body, Schema.ref(:UpdateFunctions), "Function definitions")
    end

    response(200, "OK", Schema.ref(:FunctionsResponse))
    response(403, "Forbidden")
    response(422, "Client Error")
  end

  def update(conn, params) do
    claims = conn.assigns[:current_resource]

    with :ok <- Bodyguard.permit(Functions, :replace, claims),
         {:ok, _multi} <- Functions.replace_all(params) do
      functions = Functions.list_functions()

      conn
      |> put_view(TdDqWeb.FunctionView)
      |> render("index.json", functions: functions)
    end
  end
end
