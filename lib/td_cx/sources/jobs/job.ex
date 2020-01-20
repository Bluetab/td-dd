defmodule TdCx.Sources.Jobs.Job do
  use Ecto.Schema
  import Ecto.Changeset

  alias TdCx.Sources.Source

  schema "jobs" do
    belongs_to :source, Source
    field :external_id, Ecto.UUID, autogenerate: true

    timestamps()
  end

  @doc false
  def changeset(job, attrs) do
    job
    |> cast(attrs, [:source_id])
    |> validate_required([:source_id])
  end
end
