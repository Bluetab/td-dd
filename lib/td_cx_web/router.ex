defmodule TdCxWeb.Router do
  use TdCxWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", TdCxWeb do
    pipe_through :api
  end
end
