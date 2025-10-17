defmodule TdDdWeb.Router do
  use TdDdWeb, :router

  pipeline :api do
    plug TdDd.Auth.Pipeline.Unsecure
    plug TdDd.I18n.Pipeline.Language
    plug :accepts, ["json"]
  end

  pipeline :api_auth do
    plug TdDd.Auth.Pipeline.Secure
    plug TdDd.I18n.Pipeline.Language
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
    post("/data_structures/suggestions", SuggestionController, :search)
    post("/data_structures/bulk_update", DataStructureController, :bulk_update)
    post("/data_structures/xlsx/download", DataStructures.XLSXController, :download)
    post("/data_structures/xlsx/upload", DataStructures.XLSXController, :upload)

    post(
      "/data_structures/bulk_update_template_content",
      DataStructureController,
      :bulk_update_template_content
    )

    resources(
      "/data_structures/bulk_update_template_content_events",
      FileBulkUpdateEventController,
      only: [:index]
    )

    post("/data_structures/tags/search", TagSearchController, :search)
    post("/data_structures/structure_tags/search", StructureTagSearchController, :search)
    post("/data_structures/bulk_upload_domains", DataStructureController, :bulk_upload_domains)
    post("/data_structure_notes/search", StructureNoteController, :search)
    post("/data_structure_notes/xlsx/download", DataStructures.XLSXController, :download)
    post("/data_structure_notes/xlsx/upload", DataStructures.XLSXController, :upload)
    post("/data_structure_notes", StructureNoteController, :create_by_external_id)

    resources "/data_structures", DataStructureController, except: [:new, :edit, :show] do
      resources("/versions", DataStructureVersionController, only: [:show])
      resources("/profile_results", ProfileController, only: [:create])
      resources("/notes", StructureNoteController, except: [:new, :edit], name: :note)
      post("/notes/xlsx/download", DataStructures.XLSXController, :download_notes)
      get("/note_suggestions", StructureNoteController, :note_suggestions)
      resources("/grants", GrantController, only: [:create])
      resources("/structure_links", DataStructureLinkController, only: [:index])
    end

    post("/data_structure_links", DataStructureLinkController, :create)
    post("/data_structure_links/search", DataStructureLinkController, :search)
    get("/data_structure_links/search_all", DataStructureLinkController, :index_by_external_id)

    get(
      "/data_structures/structure_links/source/:source_id/target/:target_id",
      DataStructureLinkController,
      :show
    )

    delete(
      "/data_structures/structure_links/source/:source_id/target/:target_id",
      DataStructureLinkController,
      :delete
    )

    get("/data_structure_links/search_one", DataStructureLinkController, :show_by_external_ids)

    delete(
      "/data_structure_links/search_delete_one",
      DataStructureLinkController,
      :delete_by_external_ids
    )

    delete("/labels/search_delete_one", LabelController, :delete_by_name)
    resources("/labels", LabelController)

    resources("/data_structure_versions", DataStructureVersionController, only: [:show])

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

    get("/lineage/update_nodes_domains", NodeController, :update_nodes_domains)

    resources("/nodes", NodeController, only: [:index, :show])

    resources("/units", UnitController, except: [:new, :edit], param: "name") do
      resources("/events", UnitEventController, only: [:index], name: "event")
    end

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

    post "/buckets/structures", DataStructureController, :get_bucket_structures
    post "/buckets/paths", DataStructureFilterController, :get_bucket_paths

    get("/data_structures/search/reindex_all", SearchController, :reindex_all)
    post("/data_structures/search/embeddings/_put", SearchController, :embeddings)

    get("/data_structure_filters", DataStructureFilterController, :index)
    post("/data_structure_filters/search", DataStructureFilterController, :search)

    post("/grant_filters/search", GrantFilterController, :search)
    post("/grant_filters/search/mine", GrantFilterController, :search_mine)

    get("/user_search_filters/me", UserSearchFilterController, :index_by_user)
    resources("/user_search_filters", UserSearchFilterController, except: [:new, :edit])

    resources("/relation_types", RelationTypeController, except: [:new, :edit])

    resources("/data_structure_types", DataStructureTypeController,
      only: [:index, :show, :update]
    )

    resources("/grants", GrantController, except: [:create, :new, :edit])
    get("/grants/search/reindex_all", GrantSearchController, :reindex_all_grants)
    post("/grants/search", GrantSearchController, :search_grants)
    post("/grants/search/mine", GrantSearchController, :search_my_grants)
    post("/grants/xlsx/download", GrantController, :download)

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

    post("/grant_requests/search", GrantRequestSearchController, :search)
    post("/grant_requests_filters/search", GrantRequestFilterController, :search)
    get("/grant_requests/search/reindex_all", GrantRequestSearchController, :reindex_all)
    post("/grant_requests/bulk_approval", GrantRequestBulkApprovalController, :create)

    resources("/reference_data", ReferenceDataController, except: [:edit, :new]) do
      resources("/csv", ReferenceDataDownloadController, only: [:show], singleton: true)
    end
  end
end
