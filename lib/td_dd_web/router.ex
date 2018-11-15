defmodule TdDdWeb.Router do
  use TdDdWeb, :router

  pipeline :api do
    plug TdDd.Auth.Pipeline.Unsecure
    plug :accepts, ["json"]
  end

  pipeline :api_secure do
    plug TdDd.Auth.Pipeline.Secure
  end

  pipeline :api_authorized do
    plug(TdDd.Auth.CurrentUser)
    plug(Guardian.Plug.LoadResource)
  end

  scope "/api", TdDdWeb do
    pipe_through :api
    get  "/ping", PingController, :ping
    post "/echo", EchoController, :echo
  end

  scope "/api", TdDdWeb do
    pipe_through [:api, :api_secure, :api_authorized]
    post "/td_dd/metadata", MetadataController, :upload
    resources "/data_structures", DataStructureController, except: [:new, :edit] do
      get "/comment", CommentController, :get_comment_data_structure
      get "/data_fields", DataFieldController, :data_structure_fields
    end
    post "/data_structures/search", DataStructureController, :search

    resources "/data_fields", DataFieldController, except: [:new, :edit] do
      get "/comment", CommentController, :get_comment_data_field
    end
    resources "/comments", CommentController, except: [:new, :edit]

    get "/data_structures/search/reindex_all", SearchController, :reindex_all

    get "/data_structure_filters", DataStructureFilterController, :index
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
      basePath: "/api",
      securityDefinitions:
        %{
          bearer:
          %{
            type: "apiKey",
            name: "Authorization",
            in: "header",
          }
      },
      security: [
        %{
         bearer: []
        }
      ]
    }
  end

end
