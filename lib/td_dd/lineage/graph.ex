defmodule TdDd.Lineage.Graph do
  @moduledoc """
  Ecto schema for serialized graph drawings.
  """
  use Ecto.Schema

  schema "graphs" do
    field(:pre_create_id, Ecto.UUID, virtual: true)
    field(:hash, :string)
    field(:data, :map)
    timestamps(type: :utc_datetime_usec)
  end
end
