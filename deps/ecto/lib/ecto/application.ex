defmodule Ecto.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    import Supervisor.Spec

    children = [
      worker(Ecto.Registry, []),
      supervisor(Ecto.Migration.Supervisor, [])
    ]

    opts = [strategy: :one_for_one, name: Ecto.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
