defmodule DataDictionaryWeb.Router do
  use DataDictionaryWeb, :router

  pipeline :api do
    plug DataDictionary.Auth.Pipeline.Unsecure
    plug :accepts, ["json"]
  end

  pipeline :api_secure do
    plug DataDictionary.Auth.Pipeline.Secure
  end

  scope "/api", DataDictionaryWeb do
    pipe_through :api
  end

  scope "/api", DataDictionaryWeb do
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
        title: "DataDictionary"
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
