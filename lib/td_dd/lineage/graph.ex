defmodule TdDd.Lineage.Graph do
  @moduledoc """
  Ecto schema for serialized graph drawings.
  """
  use Ecto.Schema

  schema "graphs" do
    field(:hash, :string)
    field(:params, :map)
    field(:data, :map)
    field(:is_stale, :boolean, virtual: true)
    timestamps(type: :utc_datetime_usec)
  end
end
