defmodule TdDd.DataStructures.FileBulkUpdateEvents do
  @moduledoc """
  File update Bulk Update Events
  """

  import Ecto.Query

  alias TdDd.DataStructures.BulkUpdater
  alias TdDd.DataStructures.FileBulkUpdateEvent
  alias TdDd.Repo

  def create_pending(user_id, hash, file_name, task_reference) do
    create_event(%{
      user_id: user_id,
      status: "PENDING",
      hash: hash,
      filename: file_name,
      task_reference: task_reference
    })
  end

  def create_retrying(user_id, hash, file_name, task_reference) do
    create_event(%{
      user_id: user_id,
      status: "RETRYING",
      hash: hash,
      filename: file_name,
      task_reference: task_reference
    })
  end

  def create_failed(user_id, hash, file_name, message, task_reference) do
    create_event(%{
      user_id: user_id,
      status: "FAILED",
      hash: hash,
      filename: file_name,
      message: message,
      task_reference: task_reference
    })
  end

  def create_started(user_id, hash, file_name, task_reference) do
    create_event(%{
      user_id: user_id,
      status: "STARTED",
      hash: hash,
      filename: file_name,
      task_reference: task_reference
    })
  end

  def create_completed(response, user_id, hash, file_name, task_reference) do
    create_event(%{
      response: response,
      user_id: user_id,
      hash: hash,
      filename: file_name,
      status: "COMPLETED",
      task_reference: task_reference
    })
  end

  def create_event(attrs \\ %{}) do
    %FileBulkUpdateEvent{}
    |> FileBulkUpdateEvent.changeset(attrs)
    |> Repo.insert()
  end

  def get_by_user_id(user_id) do
    FileBulkUpdateEvent
    |> where([e], e.user_id == ^user_id)
    |> order_by([e], desc: e.hash, desc: e.inserted_at)
    |> subquery()
    |> order_by([e], desc: e.inserted_at)
    |> limit(20)
    |> Repo.all()
  end

  def last_event_by_hash(hash) do
    FileBulkUpdateEvent
    |> where([e], e.hash == ^hash)
    |> order_by([e], desc: e.inserted_at)
    |> limit(1)
    |> Repo.one()
    |> check_timeout
  end

  def check_timeout(%FileBulkUpdateEvent{status: "STARTED", inserted_at: inserted_at} = event) do
    if DateTime.compare(
         DateTime.add(inserted_at, BulkUpdater.timeout(), :second),
         DateTime.utc_now()
       ) in [:lt, :eq] do
      %FileBulkUpdateEvent{event | status: "TIMED_OUT"}
    else
      %FileBulkUpdateEvent{event | status: "ALREADY_STARTED"}
    end
  end

  def check_timeout(%FileBulkUpdateEvent{} = event), do: event
  def check_timeout(_), do: nil
end
