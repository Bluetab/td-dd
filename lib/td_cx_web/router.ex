defmodule TdCxWeb.Router do
  use TdCxWeb, :router

  pipeline :api do
    plug TdCx.Auth.Pipeline.Unsecure
    plug TdCxWeb.Locale
    plug :accepts, ["json"]
  end

  pipeline :api_secure do 
    plug TdCx.Auth.Pipeline.Secure
  end

  pipeline :api_authorized do
    plug TdCx.Auth.CurrentResource
    plug Guardian.Plug.LoadResource
  end

  scope "/api/swagger" do
    forward "/", PhoenixSwagger.Plug.SwaggerUI, otp_app: :td_dd, swagger_file: "swagger_cx.json"
  end

  scope "/api", TdCxWeb do
    pipe_through :api
    get "/ping", PingController, :ping
    post "/echo", EchoController, :echo
  end

  scope "/api", TdCxWeb do
    pipe_through [:api, :api_secure, :api_authorized]

    resources "/sources", SourceController, except: [:new, :edit], param: "external_id" do
      resources("/jobs", JobController, only: [:index, :create])
    end

    resources "/jobs", JobController, only: [:show], param: "external_id" do
      resources("/events", EventController, only: [:index, :create])
    end

    resources "/configurations", ConfigurationController,
      except: [:new, :edit],
      param: "external_id" do
      resources("/sign", ConfigurationSignerController, only: [:create])
    end

    post("/jobs/search", JobController, :search)
    post("/job_filters/search", JobFilterController, :search)
    get("/jobs/search/reindex_all", SearchController, :reindex_all)
  end

  def swagger_info do
    %{
      schemes: ["http", "https"],
      info: %{
        version: :td_dd |> Application.spec(:vsn) |> to_string(),
        title: "Truedat Connector Management Service"
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
