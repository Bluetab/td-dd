defmodule TdDd.DataStructures.CsvBulkUpdateEvents do
  @moduledoc """
  CSV file update Bulk Update Events
  """

  import Ecto.Query

  alias TdDd.DataStructures.BulkUpdater
  alias TdDd.DataStructures.CsvBulkUpdateEvent
  alias TdDd.Repo

  def create_event(attrs \\ %{}) do
    %CsvBulkUpdateEvent{}
    |> CsvBulkUpdateEvent.changeset(attrs)
    |> Repo.insert()
  end

  def get_by_user_id(user_id) do
    CsvBulkUpdateEvent
    |> where([e], e.user_id == ^user_id)
    |> order_by([e], desc: e.user_id, desc: e.csv_hash, desc: e.inserted_at)
    |> subquery()
    |> order_by([e], desc: e.inserted_at)
    |> limit(20)
    |> Repo.all()
  end

  def last_event_by_hash(hash) do
    CsvBulkUpdateEvent
    |> where([e], e.csv_hash == ^hash)
    |> order_by([e], desc: e.inserted_at)
    |> limit(1)
    |> Repo.one()
    |> check_timeout
  end

  def check_timeout(%CsvBulkUpdateEvent{status: "STARTED", inserted_at: inserted_at} = event) do
    if DateTime.compare(
         DateTime.add(inserted_at, BulkUpdater.timeout(), :second),
         DateTime.utc_now()
       ) in [:lt, :eq] do
      %CsvBulkUpdateEvent{event | status: "TIMED_OUT"}
    else
      %CsvBulkUpdateEvent{event | status: "ALREADY_STARTED"}
    end
  end

  def check_timeout(%CsvBulkUpdateEvent{} = event), do: event
  def check_timeout(nil), do: nil
end
