defmodule DataDictionaryWeb.Router do
  use DataDictionaryWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", DataDictionaryWeb do
    pipe_through :api
  end
end
