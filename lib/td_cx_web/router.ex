defmodule TdCxWeb.Router do
  use TdCxWeb, :router

  @endpoint_url "#{Application.get_env(:td_cx, TdCxWeb.Endpoint)[:url][:host]}:#{Application.get_env(:td_cx, TdCxWeb.Endpoint)[:url][:port]}"

  pipeline :api do
    plug TdCx.Auth.Pipeline.Unsecure
    plug TdCxWeb.Locale
    plug :accepts, ["json"]
  end

  pipeline :api_secure do
    plug TdCx.Auth.Pipeline.Secure
  end

  pipeline :api_authorized do
    plug TdCx.Auth.CurrentUser
    plug Guardian.Plug.LoadResource
  end

  scope "/api/swagger" do
    forward "/", PhoenixSwagger.Plug.SwaggerUI, otp_app: :td_cx, swagger_file: "swagger.json"
  end

  scope "/api", TdCxWeb do
    pipe_through :api
    get  "/ping", PingController, :ping
    post "/echo", EchoController, :echo
  end

  scope "/api", TdCxWeb do
    pipe_through [:api, :api_secure, :api_authorized]

    resources "/sources", SourceController, except: [:new, :edit], param: "external_id" do
      get("/jobs", JobController, :source_jobs)
      post("/jobs", JobController, :create_job)
    end

    resources "/jobs", JobController, except: [:new, :edit, :update, :create, :show, :index, :delete], param: "external_id" do
      get("/events", EventController, :job_events)
      post("/events", EventController, :create_event)
    end
  end

  def swagger_info do
    %{
      schemes: ["http"],
      info: %{
        version: "1.0",
        title: "TdCx"
      },
      host: @endpoint_url,
      securityDefinitions:
        %{
          bearer:
          %{
            type: "apiKey",
            name: "Authorization",
            in: "header",
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
