defmodule TdDqWeb.Router do
  use TdDqWeb, :router

  pipeline :api do
    plug TdDq.Auth.Pipeline.Unsecure
    plug :accepts, ["json"]
  end

  pipeline :api_secure do
    plug TdDq.Auth.Pipeline.Secure
  end

  scope "/api/swagger" do
    forward "/", PhoenixSwagger.Plug.SwaggerUI, otp_app: :td_dq, swagger_file: "swagger.json"
  end

  scope "/api", TdDqWeb do
    pipe_through :api
  end

  scope "/api", TdDqWeb do
    pipe_through [:api, :api_secure]
  end

  scope "/api", TdDqWeb do
    pipe_through [:api, :api_secure]

    get "/quality_controls/type_parameters_file", QualityControlController, :type_parameters_file
    post "/quality_controls_results", QualityControlsResultsController, :upload
    get "/quality_controls_results", QualityControlsResultsController, :index
    resources "/quality_controls", QualityControlController, except: [:new, :edit]
  end

  def swagger_info do
    %{
      schemes: ["http"],
      info: %{
        version: "1.0",
        title: "QualityControl"
      },
      "basePath": "/api",
      "securityDefinitions":
      %{
        bearer:
        %{
          "type": "apiKey",
          "name": "Authorization",
          "in": "header",
        }
      },
      "security": [
        %{
          bearer: []
        }
      ]
    }
  end

end
