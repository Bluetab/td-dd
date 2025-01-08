defmodule TdCxWeb.Router do
  use TdCxWeb, :router

  pipeline :api do
    plug TdCx.Auth.Pipeline.Unsecure
    plug TdCxWeb.Locale
    plug :accepts, ["json"]
  end

  pipeline :api_auth do
    plug TdCx.Auth.Pipeline.Secure
  end

  scope "/api", TdCxWeb do
    pipe_through :api
    get "/ping", PingController, :ping
    post "/echo", EchoController, :echo
  end

  scope "/api", TdCxWeb do
    pipe_through [:api, :api_auth]

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
end
