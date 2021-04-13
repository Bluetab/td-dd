defmodule TdDd.Events.ProfileEvents do
  @moduledoc """
  The Events context.
  """

  import Ecto.Query, warn: false

  alias TdDd.Events.ProfileEvent
  alias TdDd.Repo

  def create_event(attrs \\ %{}) do
    attrs
    |> ProfileEvent.create_changeset()
    |> Repo.insert()
  end
end
