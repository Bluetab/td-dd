defmodule TdDq.Events.QualityEvents do
  @moduledoc """
  Quality Events context
  """

  import Ecto.Query

  alias TdDd.Repo
  alias TdDq.Events.QualityEvent
  alias TdDq.Executions.Execution
  alias TdDq.Implementations.Implementation
  alias TdDq.Rules.Audit
  alias TdDq.Search.IndexWorker

  def create_event(attrs \\ %{}) do
    %QualityEvent{}
    |> QualityEvent.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, %QualityEvent{} = event} ->
        %{execution: exec} = Repo.preload(event, :execution)

        if event.type === "FAILED" do
          publish_errored_event(event, exec)
          IndexWorker.reindex_implementations(exec.implementation_id)
        end

        {:ok, event}

      error ->
        error
    end
  end

  defp publish_errored_event(event, exec) do
    %{implementation: implementation} = Repo.preload(exec, :implementation)

    errored_result = %{
      id: event.id,
      date: event.inserted_at,
      message: Map.get(event, :message, "Quality execution error"),
      status: "error",
      domain_id: implementation.domain_id,
      # rule_results event payload uses implementation_ref instead of ID.
      # to track multiple implementation versions.
      implementation_ref: implementation.implementation_ref,
      implementation_key: implementation.implementation_key,
      rule_id: implementation.rule_id
    }

    Audit.rule_results_created(nil, %{results: [errored_result]}, 0)
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

  def get_last_event_by_imp(%{implementation_ref: ref}) do
    implementation_ids =
      Implementation
      |> where(implementation_ref: ^ref)
      |> select([i], i.id)

    QualityEvent
    |> join(:left, [qe], e in Execution, on: qe.execution_id == e.id)
    |> where([_, e], e.implementation_id in subquery(implementation_ids))
    |> order_by(desc: :inserted_at)
    |> limit(1)
    |> Repo.one()
  end
end
