defmodule TdDdWeb.Router do
  use TdDdWeb, :router

  pipeline :api do
    plug TdDd.Auth.Pipeline.Unsecure
    plug :accepts, ["json"]
  end

  pipeline :api_secure do
    plug TdDd.Auth.Pipeline.Secure
  end

  scope "/api", TdDdWeb do
    pipe_through :api
  end

  scope "/api", TdDdWeb do
    pipe_through [:api, :api_secure]
    post "/metadata", MetadataController, :upload
    resources "/data_structures", DataStructureController, except: [:new, :edit]
    resources "/data_fields", DataFieldController, except: [:new, :edit]
    resources "/comments", CommentController, except: [:new, :edit]
  end

  scope "/api/swagger" do
    forward "/", PhoenixSwagger.Plug.SwaggerUI, otp_app: :td_dd, swagger_file: "swagger.json"
  end

  def swagger_info do
    %{
      schemes: ["http"],
      info: %{
        version: "1.0",
        title: "TdDd"
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
