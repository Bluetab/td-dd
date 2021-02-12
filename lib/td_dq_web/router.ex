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
    forward("/", PhoenixSwagger.Plug.SwaggerUI, otp_app: :td_dq, swagger_file: "swagger.json")
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
    resources("/executions", ExecutionController, only: [:index])

    post("/rule_results", RuleResultController, :upload)
    resources("/rule_results", RuleResultController, only: [:index, :delete])

    get("/rules/concept/:id", RuleController, :get_rules_by_concept)

    resources "/rules", RuleController, except: [:new, :edit] do
      post("/rule_implementations", ImplementationController, :search_rule_implementations)
    end

    post("/rules/search", SearchController, :search_rules)
    get("/rules/search/reindex_all", SearchController, :reindex_all_rules)

    get(
      "/rule_implementations/search/reindex_all",
      SearchController,
      :reindex_all_implementations
    )

    post("/rule_filters/search", RuleFilterController, :search)
    post("/rule_implementation_filters/search", ImplementationFilterController, :search)
    resources("/rule_implementations", ImplementationController, except: [:new, :edit])
    post("/rule_implementations/csv", ImplementationController, :csv)
    post("/rule_implementations/search", SearchController, :search_implementations)
  end

  def swagger_info do
    %{
      schemes: ["http", "https"],
      info: %{
        version: Application.spec(:td_dq, :vsn),
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
