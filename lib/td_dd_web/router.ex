defmodule TdDdWeb.Router do
  use TdDdWeb, :router

  pipeline :api do
    plug TdDd.Auth.Pipeline.Unsecure
    plug :accepts, ["json"]
  end

  pipeline :api_auth do
    plug TdDd.Auth.Pipeline.Secure
  end

  scope "/api", TdDdWeb do
    pipe_through :api
    get("/ping", PingController, :ping)
    post("/echo", EchoController, :echo)
  end

  scope "/api" do
    pipe_through [:api, :api_auth]
    forward "/v2", Absinthe.Plug, schema: TdDdWeb.Schema
  end

  scope "/api", TdDdWeb do
    pipe_through [:api, :api_auth]

    patch("/data_structures/metadata", MetadataController, :upload)
    post("/data_structures/metadata", MetadataController, :upload)
    post("/data_structures/search", DataStructureController, :search)
    post("/data_structures/bulk_update", DataStructureController, :bulk_update)
    post("/data_structures/csv", DataStructureController, :csv)
    post("/data_structures/editable_csv", DataStructureController, :editable_csv)

    post(
      "/data_structures/bulk_update_template_content",
      DataStructureController,
      :bulk_update_template_content
    )

    resources(
      "/data_structures/bulk_update_template_content_events",
      CsvBulkUpdateEventController,
      only: [:index]
    )

    post(
      "/data_structures/bulk_upload_domains",
      DataStructureController,
      :bulk_upload_domains
    )

    post("/data_structure_notes/search", StructureNoteController, :search)
    post("/data_structure_notes", StructureNoteController, :create_by_external_id)

    resources "/data_structures", DataStructureController, except: [:new, :edit, :show] do
      resources("/versions", DataStructureVersionController, only: [:show])
      resources("/profile_results", ProfileController, only: [:create])
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

    get "/graphs/hash/:hash", GraphController, :get_graph_by_hash
    post("/graphs/csv", GraphController, :csv)
    resources("/graphs", GraphController, only: [:create, :show])

    resources("/lineage_events", LineageEventController, only: [:index])

    resources("/nodes", NodeController, only: [:index, :show])

    resources("/units", UnitController, except: [:new, :edit], param: "name") do
      resources("/events", UnitEventController, only: [:index], name: "event")
    end

    resources("/unit_domains", UnitDomainController, only: [:index])

    post("/profiles/search", ProfileController, :search)
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

    get("/data_structure_filters", DataStructureFilterController, :index)
    post("/data_structure_filters/search", DataStructureFilterController, :search)

    post("/grant_filters/search", GrantFilterController, :search)
    post("/grant_filters/search/mine", GrantFilterController, :search_mine)

    get("/user_search_filters/me", UserSearchFilterController, :index_by_user)
    resources("/user_search_filters", UserSearchFilterController, except: [:new, :edit])

    resources("/relation_types", RelationTypeController, except: [:new, :edit])

    resources("/data_structure_types", DataStructureTypeController, only: [:index, :show, :update])

    resources("/grants", GrantController, except: [:create, :new, :edit])
    get("/grants/search/reindex_all", GrantSearchController, :reindex_all_grants)
    post("/grants/search", GrantSearchController, :search_grants)
    post("/grants/search/mine", GrantSearchController, :search_my_grants)
    post("/grants/csv", GrantController, :csv)

    resources("/grants_bulk", GrantsController, only: [:update], singleton: true)

    resources("/accesses/bulk_load", AccessController, only: [:create], singleton: true)

    resources("/grant_request_groups", GrantRequestGroupController,
      only: [:index, :show, :create, :delete]
    ) do
      resources("/grant_requests", GrantRequestController, only: [:index], name: "request")
    end

    resources("/grant_requests", GrantRequestController, only: [:index, :show, :delete]) do
      resources("/approvals", GrantRequestApprovalController, only: [:create], name: "approval")
      resources("/status", GrantRequestStatusController, only: [:create], name: "status")
    end

    resources("/reference_data", ReferenceDataController, except: [:edit, :new]) do
      resources("/csv", ReferenceDataDownloadController, only: [:show], singleton: true)
    end
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
