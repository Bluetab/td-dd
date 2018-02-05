defmodule DataQualityWeb.Router do
  use DataQualityWeb, :router

  pipeline :api do
    plug DataQuality.Auth.Pipeline.Unsecure
    plug :accepts, ["json"]
  end

  pipeline :api_secure do
    plug DataQuality.Auth.Pipeline.Secure
  end

  scope "/api", DataQualityWeb do
    pipe_through :api
  end

  scope "/api", DataQualityWeb do
    pipe_through [:api, :api_secure]
  end

  scope "/api", DataQualityWeb do
    pipe_through [:api, :api_secure]
    resources "/quality_controls", QualityControlController, except: [:new, :edit]

  end

end
