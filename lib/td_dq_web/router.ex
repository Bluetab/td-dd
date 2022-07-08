defmodule TdDqWeb.Router do
  use TdDqWeb, :router

  pipeline :api do
    plug(TdDq.Auth.Pipeline.Unsecure)
    plug(:accepts, ["json"])
  end

  pipeline :api_secure do
    plug(TdDq.Auth.Pipeline.Secure)
  end

  scope "/api/swagger" do
    forward("/", PhoenixSwagger.Plug.SwaggerUI, otp_app: :td_dd, swagger_file: "swagger_dq.json")
  end

  scope "/api", TdDqWeb do
    pipe_through(:api)
    get("/ping", PingController, :ping)
    post("/echo", EchoController, :echo)
  end

  scope "/api", TdDqWeb do
    pipe_through([:api, :api_secure])

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

    resources("/rules", RuleController, except: [:new, :edit]) do
      post("/rule_implementations", ImplementationController, :search_rule_implementations)
    end

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
  end

  def swagger_info do
    %{
      schemes: ["http", "https"],
      info: %{
        version: Application.spec(:td_dd, :vsn),
        title: "Truedat Data Quality Service"
      },
      basePath: "/",
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
