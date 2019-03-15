defmodule TdDdWeb do
  @moduledoc """
  The entrypoint for defining your web interface, such
  as controllers, views, channels and so on.

  This can be used in your application as:

      use TdDdWeb, :controller
      use TdDdWeb, :view

  The definitions below will be executed for every view,
  controller, etc, so keep them short and clean, focused
  on imports, uses and aliases.

  Do NOT define functions inside the quoted expressions
  below. Instead, define any helper function in modules
  and import those modules here.
  """

  def controller(log \\ :info) do
    quote bind_quoted: [log: log] do
      use Phoenix.Controller, namespace: TdDdWeb, log: log
      import Plug.Conn
      import TdDdWeb.Gettext
      alias TdDdWeb.Router.Helpers, as: Routes
    end
  end

  def view do
    quote do
      use Phoenix.View,
        root: "lib/td_dd_web/templates",
        namespace: TdDdWeb

      # Import convenience functions from controllers
      import Phoenix.Controller, only: [get_flash: 2, view_module: 1]

      import TdDdWeb.ErrorHelpers
      import TdDdWeb.Gettext
      alias TdDdWeb.Router.Helpers, as: Routes
    end
  end

  def router do
    quote do
      use Phoenix.Router
      import Plug.Conn
      import Phoenix.Controller
    end
  end

  def channel do
    quote do
      use Phoenix.Channel
      import TdDdWeb.Gettext
    end
  end

  @doc """
  When used, dispatch to the appropriate controller/view/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end

  @doc """
  Custom log level for controllers
  """
  defmacro __using__([:controller = which, log]) do
    apply(__MODULE__, which, [log])
  end
end
