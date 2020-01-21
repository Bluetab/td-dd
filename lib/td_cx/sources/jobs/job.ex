defmodule TdCx.Sources.Jobs.Job do
  @moduledoc "Job entity"
  use Ecto.Schema
  import Ecto.Changeset

  alias TdCx.Sources.Events.Event
  alias TdCx.Sources.Jobs.Job
  alias TdCx.Sources.Source

  schema "jobs" do
    belongs_to(:source, Source)
    has_many(:events, Event)
    field(:external_id, Ecto.UUID, autogenerate: true)

    timestamps()
  end

  @doc false
  def changeset(job, attrs) do
    job
    |> cast(attrs, [:source_id])
    |> validate_required([:source_id])
  end

  defimpl Elasticsearch.Document do
    @impl Elasticsearch.Document
    def id(%Job{id: id}), do: id

    @impl Elasticsearch.Document
    def routing(_), do: false

    @impl Elasticsearch.Document
    def encode(%Job{source: source, events: events} = job) do
      job
      |> Map.take([
        :id,
        :external_id
      ])
      |> Map.merge(%{source: Map.take(source, [:external_id, :type])})
      |> Map.merge(metrics(events))
    end

    defp metrics([]), do: Map.new()

    defp metrics(events) do
      {min, max} = Enum.min_max_by(events, fn %{date: date} -> Date.to_erl(date) end)

      Map.new()
      |> Map.put(:start_date, Map.get(min, :date))
      |> Map.put(:end_date, Map.get(max, :date))
      |> Map.put(:status, Map.get(max, :type))
      |> Map.put(:message, Map.get(max, :message))
    end
  end
end
