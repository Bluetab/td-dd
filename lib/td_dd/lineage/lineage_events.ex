defmodule TdDd.Lineage.LineageEvents do
  @moduledoc """
  Quality Events context
  """

  import Ecto.Query

  alias TdDd.Repo
  alias TdDd.Lineage.LineageEvent

  def create_event(attrs \\ %{}) do
    %LineageEvent{}
    |> LineageEvent.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, %LineageEvent{} = event} ->
        #%{execution: exec} = Repo.preload(event, :execution)

        # if event.type === "FAILED" do
        #   IndexWorker.reindex_implementations(exec.implementation_id)
        # end
        {:ok, event}

      error ->
        error
    end
  end

  def get_by_user_id(user_id) do
    LineageEvent
    |> where(user_id: ^user_id)
    |> Repo.all()
  end

  defmacro array_agg(field) do
    quote do: fragment("array_agg(?)", unquote(field))
  end

  def pending_by_user_id(user_id) do
    pending(user_id, nil)
  end

  def pending_by_hash(hash) do
    pending(nil, hash)
  end

  def pending(user_id, hash) do

    inner_query = "lineage_events"
    |> maybe_where_hash(hash)
    |> maybe_where_user(user_id)
    |> select([le], %{graph_hash: le.graph_hash, graph_data: le.graph_data, task_reference: le.task_reference, statuses: fragment("array_agg(status)"), inserted_at_agg: fragment("array_agg(inserted_at)")})
    |> group_by([le], [le.graph_hash, le.graph_data, le.task_reference])

    subquery(inner_query)
    |> where([iq], fragment("? = ANY (?)", "STARTED", iq.statuses) and not (fragment("? = ANY (?)", "COMPLETED", iq.statuses)) or fragment("? = ANY (?)", "FAILED", iq.statuses))
    |> select([iq], %{graph_hash: iq.graph_hash, graph_data: iq.graph_data, task_reference: iq.task_reference, statuses: iq.statuses, inserted_at: fragment("inserted_at_agg[1]")})
    |> order_by([iq], [desc: iq.inserted_at_agg])
    |> maybe_limit(hash)
    |> repo(hash)
  end

  defp maybe_where_hash(query, nil) do
    query
  end
  defp maybe_where_hash(query, hash) do
    query |> where([le], le.graph_hash == ^hash)
  end

  defp maybe_where_user(query, nil) do
    query
  end
  defp maybe_where_user(query, user_id) do
    query |> where([le], le.user_id == ^user_id)
  end

  defp maybe_limit(query, nil = _hash) do
    query
  end
  # There could be more than one pair of STARTED/COMPLETED entries for the
  # same hash if graph table has been cleared, so limit(1)
  defp maybe_limit(query, _hash) do
    query |> limit(1)
  end

  defp repo(query, nil = _hash) do
    query
    |> Repo.all()
    |> Enum.map(
      fn event ->
        event |> Map.drop([:statuses]) |> Map.put_new(:status, "already_started")
      end
    )
  end
  defp repo(query, _hash) do
    case Repo.one(query) do
      nil -> nil
      event -> event |> Map.drop([:statuses]) |> Map.put_new(:status, "already_started")
    end
  end

end
