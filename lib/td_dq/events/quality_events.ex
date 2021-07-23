defmodule TdDq.Events.QualityEvents do
  @moduledoc """
  Quality Events context
  """

  import Ecto.Query

  alias TdDd.Repo
  alias TdDq.Events.QualityEvent
  alias TdDq.Executions.Execution
  alias TdDq.Search.IndexWorker

  def create_event(attrs \\ %{}) do
    %QualityEvent{}
    |> QualityEvent.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, %QualityEvent{} = event} ->
        %{execution: exec} = Repo.preload(event, :execution)

        if event.type === "FAILED" do
          IndexWorker.reindex_implementations(exec.implementation_id)
        end

        {:ok, event}

      error ->
        error
    end
  end

  def complete(execution_ids) do
    inserted_at = DateTime.utc_now()

    events =
      execution_ids
      |> Enum.map(fn %{id: id} ->
        %{
          execution_id: id,
          type: "SUCCEEDED",
          message: "Quality Completed",
          inserted_at: inserted_at
        }
      end)

    Repo.insert_all(QualityEvent, events, returning: true)
  end

  def get_event_by_imp(implementation_id) do
    QualityEvent
    |> join(:left, [qe], e in Execution, on: qe.execution_id == e.id)
    |> where([_, e], e.implementation_id == ^implementation_id)
    |> order_by(desc: :inserted_at)
    |> limit(1)
    |> Repo.one()
  end
end
