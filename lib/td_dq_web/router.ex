defmodule TdDqWeb.Router do
  use TdDqWeb, :router

  pipeline :api do
    plug TdDq.Auth.Pipeline.Unsecure
    plug TdCore.I18n.Plug.Language
    plug :accepts, ["json"]
  end

  pipeline :api_auth do
    plug TdDq.Auth.Pipeline.Secure
    plug TdCore.I18n.Plug.Language
  end

  scope "/api", TdDqWeb do
    pipe_through :api
    get("/ping", PingController, :ping)
    post("/echo", EchoController, :echo)
  end

  scope "/api", TdDqWeb do
    pipe_through [:api, :api_auth]

    resources "/execution_groups", ExecutionGroupController, except: [:new, :edit] do
      resources("/executions", ExecutionController, only: [:index])
    end

    resources "/executions", ExecutionController, only: [:index] do
      resources("/quality_events", QualityEventController, only: [:create])
    end

    resources("/executions/search", ExecutionSearchController, only: [:create], singleton: true)

    post("/rule_results/search", RuleResultSearchController, :create)

    resources("/rule_results", RuleResultController, only: [:index, :delete, :create, :show]) do
      resources("/remediation", RemediationController, singleton: true)
      get("/segment_results", SegmentResultController, :index)
    end

    post("/segment_results", SegmentResultController, :index)

    get("/rules/concept/:business_concept_id", RuleController, :get_rules_by_concept)

    resources("/rules/upload", RuleUploadController, only: [:create])

    post("/rules/rule_implementations", ImplementationController, :search_rule_implementations)

    resources("/rules", RuleController, except: [:new, :edit])

    resources("/rules/search", RuleSearchController, only: [:create], singleton: true)
    get("/rules/search/reindex_all", RuleSearchController, :reindex)

    post("/rule_filters/search", RuleFilterController, :search)
    post("/rule_implementation_filters/search", ImplementationFilterController, :search)

    resources("/rule_implementations", ImplementationController, except: [:new, :edit]) do
      resources("/results", ImplementationResultController, only: [:create])
      resources("/data_structures", ImplementationStructureController, only: [:create])
    end

    resources("/rule_implementations/data_structures", ImplementationStructureController,
      only: [:delete]
    )

    resources("/rule_implementations/upload", ImplementationUploadController, only: [:create])

    resources("/rule_implementations/search", ImplementationSearchController,
      only: [:create],
      singleton: true
    )

    get("/rule_implementations/search/reindex_all", ImplementationSearchController, :reindex)

    post("/rule_implementations/csv", ImplementationController, :csv)
    post("/rule_implementations/xlsx/download", Implementation.XLSXController, :download)
    post("/rule_implementations/xlsx/upload", Implementation.XLSXController, :upload)
    get("/rule_implementations/xlsx/upload_jobs", Implementation.XLSXController, :upload_jobs)

    get(
      "/rule_implementations/xlsx/upload_jobs/:job_id",
      Implementation.XLSXController,
      :upload_job
    )

    resources("/functions", FunctionsController, only: [:update], singleton: true)
    resources("/functions", FunctionController, only: [:index, :create, :delete])
  end
end
