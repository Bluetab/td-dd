defmodule TdDDWeb.Router do
  use TdDDWeb, :router

  pipeline :api do
    plug TdDD.Auth.Pipeline.Unsecure
    plug :accepts, ["json"]
  end

  pipeline :api_secure do
    plug TdDD.Auth.Pipeline.Secure
  end

  scope "/api", TdDDWeb do
    pipe_through :api
  end

  scope "/api", TdDDWeb do
    pipe_through [:api, :api_secure]
    post "/metadata", MetadataController, :upload
    resources "/data_structures", DataStructureController, except: [:new, :edit]
    resources "/data_fields", DataFieldController, except: [:new, :edit]
  end

  def swagger_info do
    %{
      schemes: ["http"],
      info: %{
        version: "1.0",
        title: "TdDD"
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
