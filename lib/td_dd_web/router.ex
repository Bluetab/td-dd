defmodule TdDdWeb.Router do
  use TdDdWeb, :router

  pipeline :api do
    plug(TdDd.Auth.Pipeline.Unsecure)
    plug(:accepts, ["json"])
  end

  pipeline :api_secure do
    plug(TdDd.Auth.Pipeline.Secure)
  end

  pipeline :api_authorized do
    plug(TdDd.Auth.CurrentUser)
    plug(Guardian.Plug.LoadResource)
  end

  scope "/api", TdDdWeb do
    pipe_through(:api)
    get("/ping", PingController, :ping)
    post("/echo", EchoController, :echo)
  end

  scope "/api", TdDdWeb do
    pipe_through([:api, :api_secure, :api_authorized])

    resources "/data_structures", DataStructureController, except: [:new, :edit] do
      get("/comment", CommentController, :get_comment_data_structure)
      resources("/versions", DataStructureVersionController, only: [:show])
    end

    resources("/data_structure_versions", DataStructureVersionController, only: [:show])

    post("/data_structures/search", DataStructureController, :search)
    post("/data_structures/metadata", MetadataController, :upload)
    post("/data_structures/bulk_update", DataStructureController, :bulk_update)

    resources("/comments", CommentController, except: [:new, :edit])

    get("/systems/:system_external_id/structures/:structure_external_id", DataStructureController, :get_structure_by_external_ids)
    post("/structures/:external_id/profiles", ProfileController, :load_profile)

    resources("/systems", SystemController, except: [:new, :edit]) do
      post("/metadata", MetadataController, :upload_by_system)
      get("/structures", DataStructureController, :get_system_structures)
    end

    get("/data_structures/search/reindex_all", SearchController, :reindex_all)

    get("/data_structure_filters", DataStructureFilterController, :index)
    post("/data_structure_filters/search", DataStructureFilterController, :search)
  end

  scope "/api/swagger" do
    forward("/", PhoenixSwagger.Plug.SwaggerUI, otp_app: :td_dd, swagger_file: "swagger.json")
  end

  def swagger_info do
    %{
      schemes: ["http", "https"],
      info: %{
        version: Application.spec(:td_dd, :vsn),
        title: "Truedat Data Dictionary Service"
      },
      securityDefinitions: %{
        bearer: %{
          type: "apiKey",
          name: "Authorization",
          in: "header"
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
