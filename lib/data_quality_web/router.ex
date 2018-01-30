defmodule DataQualityWeb.Router do
  use DataQualityWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", DataQualityWeb do
    pipe_through :api
  end
end
