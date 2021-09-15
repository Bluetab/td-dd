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
    plug(TdDd.Auth.CurrentResource)
    plug(Guardian.Plug.LoadResource)
  end

  scope "/api", TdDdWeb do
    pipe_through(:api)
    get("/ping", PingController, :ping)
    post("/echo", EchoController, :echo)
  end

  scope "/api" do
    pipe_through([:api, :api_secure, :api_authorized])

    forward("/v2", Absinthe.Plug, schema: TdDdWeb.Schema)
  end

  scope "/api", TdDdWeb do
    pipe_through([:api, :api_secure, :api_authorized])

    patch("/data_structures/metadata", MetadataController, :upload)
    post("/data_structures/metadata", MetadataController, :upload)
    post("/data_structures/search", DataStructureController, :search)
    post("/data_structures/bulk_update", DataStructureController, :bulk_update)
    post("/data_structures/csv", DataStructureController, :csv)

    post(
      "/data_structures/bulk_update_template_content",
      DataStructureController,
      :bulk_update_template_content
    )

    post("/data_structure_notes/search", StructureNoteController, :search)
    post("/data_structure_notes", StructureNoteController, :create_by_external_id)

    resources "/data_structures", DataStructureController, except: [:new, :edit, :show] do
      resources("/versions", DataStructureVersionController, only: [:show])
      resources("/profile_results", ProfileController, only: [:create])

      resources("/tags", DataStructuresTagsController,
        only: [:delete, :index, :update],
        name: :tags
      )

      resources("/notes", StructureNoteController, except: [:new, :edit], name: :note)
      resources("/grants", GrantController, only: [:create])
    end

    resources("/data_structure_versions", DataStructureVersionController, only: [:show]) do
      post("/links", DataStructureLinkController, :create_link)
    end

    resources("/profile_execution_groups", ProfileExecutionGroupController, except: [:new, :edit])

    resources "/profile_executions", ProfileExecutionController, only: [:index, :show] do
      resources("/profile_events", ProfileEventController, only: [:create])
    end

    resources("/profile_executions/search", ProfileExecutionSearchController,
      only: [:create],
      singleton: true
    )

    post("/graphs/csv", GraphController, :csv)
    resources("/graphs", GraphController, only: [:create, :show])

    resources("/nodes", NodeController, only: [:index, :show])

    resources("/units", UnitController, except: [:new, :edit], param: "name") do
      resources("/events", UnitEventController, only: [:index], name: "event")
    end

    resources("/unit_domains", UnitDomainController, only: [:index])

    post("/profiles/upload", ProfileController, :upload)

    resources("/systems", SystemController, except: [:new, :edit]) do
      resources("/metadata", SystemMetadataController,
        only: [:update],
        as: :metadata,
        singleton: true
      )

      resources("/metadata", SystemMetadataController, only: [:create], as: :metadata)
      get("/structures", DataStructureController, :get_system_structures)
      resources("/groups", GroupController, only: [:index, :delete])
      resources("/classifiers", ClassifierController, only: [:index, :show, :create, :delete])
    end

    get("/data_structures/search/reindex_all", SearchController, :reindex_all)
    get("/grants/search/reindex_all", SearchController, :reindex_all_grants)

    get("/data_structure_filters", DataStructureFilterController, :index)
    post("/data_structure_filters/search", DataStructureFilterController, :search)

    get("/grant_filters", GrantFilterController, :index)
    post("/grant_filters/search", GrantFilterController, :search)

    get("/data_structure_user_filters/user/me", UserSearchFilterController, :index_by_user)
    resources("/data_structure_user_filters", UserSearchFilterController, except: [:new, :edit])

    resources("/relation_types", RelationTypeController, except: [:new, :edit])

    resources("/data_structure_types", DataStructureTypeController, only: [:index, :show, :update])

    resources("/data_structure_tags", DataStructureTagController, except: [:new, :edit])

    resources("/grants", GrantController, except: [:create, :new, :edit])
    post("/grants/search", SearchController, :search_grants)

    resources("/grant_request_groups", GrantRequestGroupController,
      only: [:index, :show, :create, :delete]
    ) do
      resources("/grant_requests", GrantRequestController,
        only: [:create, :index],
        name: "request"
      )
    end

    resources("/grant_requests", GrantRequestController, only: [:show, :update, :delete])
  end

  scope "/api/swagger" do
    forward("/", PhoenixSwagger.Plug.SwaggerUI, otp_app: :td_dd, swagger_file: "swagger.json")
  end

  def swagger_info do
    %{
      schemes: ["http", "https"],
      info: %{
        version: :td_dd |> Application.spec(:vsn) |> to_string(),
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
