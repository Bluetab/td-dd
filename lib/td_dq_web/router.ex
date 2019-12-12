defmodule TdDqWeb.Router do
  use TdDqWeb, :router

  @endpoint_url "#{Application.get_env(:td_dq, TdDqWeb.Endpoint)[:url][:host]}:#{Application.get_env(:td_dq, TdDqWeb.Endpoint)[:http][:port]}"

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

    post("/rule_results", RuleResultController, :upload)
    get("/rule_results", RuleResultController, :index)
    get("/rules/concept/:id", RuleController, :get_rules_by_concept)

    resources "/rules", RuleController, except: [:new, :edit] do
      post("/rule_implementations", RuleImplementationController, :search_rule_implementations)
    end

    post("/rules/execute", RuleController, :execute_rules)

    post("/rules/search", SearchController, :search)
    get("/rules/search/reindex_all", SearchController, :reindex_all)

    post("/rule_filters/search", RuleFilterController, :search)
    resources("/rule_implementations", RuleImplementationController, except: [:new, :edit])
    post("/rule_implementations/search", RuleImplementationController, :search_rules_implementations)
  end

  def swagger_info do
    %{
      schemes: ["http"],
      info: %{
        version: "1.0",
        title: "Rules"
      },
      host: @endpoint_url,
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
