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
    plug(TdDdWeb.SearchPermissionPlug)
  end

  scope "/api", TdDdWeb do
    pipe_through(:api)
    get("/ping", PingController, :ping)
    post("/echo", EchoController, :echo)
  end

  scope "/api", TdDdWeb do
    pipe_through([:api, :api_secure, :api_authorized])

    patch("/data_structures/metadata", MetadataController, :upload)
    post("/data_structures/metadata", MetadataController, :upload)
    post("/data_structures/search", DataStructureController, :search)
    post("/data_structures/bulk_update", DataStructureController, :bulk_update)
    post("/data_structures/csv", DataStructureController, :csv)

    resources "/data_structures", DataStructureController, except: [:new, :edit, :show] do
      get("/comment", CommentController, :get_comment_data_structure)
      resources("/versions", DataStructureVersionController, only: [:show])
    end

    resources("/data_structure_versions", DataStructureVersionController, only: [:show]) do
      post("/links", DataStructureLinkController, :create_link)
    end

    resources("/comments", CommentController, except: [:new, :edit])

    resources("/graphs", GraphController, only: [:create, :show])

    resources("/nodes", NodeController, only: [:index, :show])

    post("/profiles/upload", ProfileController, :upload)

    resources("/systems", SystemController, except: [:new, :edit]) do
      post("/metadata", MetadataController, :upload_by_system)
      get("/structures", DataStructureController, :get_system_structures)
      resources("/groups", GroupController, only: [:index, :delete])
    end

    get("/data_structures/search/reindex_all", SearchController, :reindex_all)

    get("/data_structure_filters", DataStructureFilterController, :index)
    post("/data_structure_filters/search", DataStructureFilterController, :search)

    resources "/relation_types", RelationTypeController, except: [:new, :edit]

    post("/td_dl/metadata", MetadataController, :upload)
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
