defmodule TdDd.Lineage.LineageEvents do
  @moduledoc """
  Lineage events context
  """

  import Ecto.Query

  alias TdDd.Lineage.LineageEvent
  alias TdDd.Repo

  defdelegate authorize(action, user, params), to: TdDd.Lineage.Policy

  def create_event(attrs \\ %{}) do
    %LineageEvent{}
    |> LineageEvent.changeset(attrs)
    |> Repo.insert()
  end

  def get_by_user_id(user_id) do
    LineageEvent
    |> where([le], le.user_id == ^user_id)
    |> distinct([le], [le.user_id, le.graph_hash])
    |> order_by([le], desc: le.user_id, desc: le.graph_hash, desc: le.inserted_at)
    |> subquery()
    |> order_by([le], desc: le.inserted_at)
    |> limit(20)
    |> Repo.all()
  end

  def last_event_by_hash(hash) do
    LineageEvent
    |> where([le], le.graph_hash == ^hash)
    |> order_by([le], desc: le.inserted_at)
    |> limit(1)
    |> Repo.one()
    |> check_timeout
  end

  def check_timeout(%LineageEvent{status: "STARTED", inserted_at: inserted_at} = event) do
    if DateTime.compare(
         DateTime.add(inserted_at, TdDd.Lineage.timeout(), :millisecond),
         DateTime.utc_now()
       ) in [:lt, :eq] do
      %LineageEvent{event | status: "TIMED_OUT"}
    else
      %LineageEvent{event | status: "ALREADY_STARTED"}
    end
  end

  def check_timeout(%LineageEvent{} = event), do: event
  def check_timeout(nil), do: nil
end
