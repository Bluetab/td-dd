defmodule TdCx.Jobs.Job do
  @moduledoc """
  Ecto Schema module for jobs
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias TdCx.Events.Event
  alias TdCx.Jobs
  alias TdCx.Jobs.Job
  alias TdCx.Sources.Source

  schema "jobs" do
    field(:external_id, Ecto.UUID, autogenerate: true)
    field(:type, :string)
    belongs_to(:source, Source)
    has_many(:events, Event)
    timestamps()
  end

  def changeset(job, attrs) do
    job
    |> cast(attrs, [:source_id, :type])
    |> validate_required([:source_id])
  end

  defimpl Elasticsearch.Document do
    @impl Elasticsearch.Document
    def id(%Job{id: id}), do: id

    @impl Elasticsearch.Document
    def routing(_), do: false

    @impl Elasticsearch.Document
    def encode(%Job{source: source, events: events} = job) do
      source = Map.take(source, [:external_id, :type])
      type = Map.get(job, :type) || ""

      job
      |> Map.take([:id, :external_id, :type])
      |> Map.put(:type, type)
      |> Map.put(:status, "")
      |> Map.put(:source, source)
      |> Map.merge(Jobs.metrics(events))
    end
  end
end
