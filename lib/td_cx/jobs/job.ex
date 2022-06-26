defmodule TdCx.Jobs.Job do
  @moduledoc """
  Ecto Schema module for jobs
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias TdCx.Events.Event
  alias TdCx.Jobs.Job
  alias TdCx.Sources.Source
  alias TdDfLib.Validation

  schema "jobs" do
    field(:external_id, Ecto.UUID, autogenerate: true)
    field(:type, :string)
    field(:parameters, :map, default: %{})
    belongs_to(:source, Source)
    has_many(:events, Event)
    # Note: updated_at is updated with most recent event's inserted_at
    timestamps(type: :utc_datetime_usec)
  end

  def changeset(job, attrs) do
    job
    |> cast(attrs, [:source_id, :type, :parameters])
    |> validate_required(:source_id)
    |> validate_change(:parameters, &Validation.validate_safe/2)
  end

  defimpl Elasticsearch.Document do
    alias TdCx.Jobs

    @default_status "PENDING"
    @max_message_length 1_000

    @impl Elasticsearch.Document
    def id(%Job{id: id}), do: id

    @impl Elasticsearch.Document
    def routing(_), do: false

    @impl Elasticsearch.Document
    def encode(
          %Job{source: source, events: events, inserted_at: inserted_at, updated_at: updated_at} =
            job
        ) do
      source = Map.take(source, [:external_id, :type])
      type = Map.get(job, :type) || ""

      job
      |> Map.take([:id, :external_id, :source_id])
      |> Map.put(:type, type)
      |> Map.put(:source, source)
      |> Map.merge(Jobs.metrics(events, max_length: @max_message_length))
      |> Map.put_new(:start_date, inserted_at)
      |> Map.put_new(:end_date, updated_at)
      |> Map.put_new(:status, @default_status)
    end
  end
end
