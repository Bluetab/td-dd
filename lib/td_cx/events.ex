defmodule TdCx.Events do
  @moduledoc """
  The Events context.
  """

  import Ecto.Query

  alias Ecto.Multi
  alias TdCx.Events.Event
  alias TdCx.Jobs.Audit
  alias TdCx.Jobs.Job
  alias TdCx.Search.IndexWorker
  alias TdDd.Repo

  @doc """
  Returns the list of events.

  ## Examples

      iex> list_events()
      [%Event{}, ...]

  """
  def list_events do
    Repo.all(Event)
  end

  @doc """
  Gets a single event.

  Raises `Ecto.NoResultsError` if the Event does not exist.

  ## Examples

      iex> get_event!(123)
      %Event{}

      iex> get_event!(456)
      ** (Ecto.NoResultsError)

  """
  def get_event!(id), do: Repo.get!(Event, id)

  @doc """
  Creates a event.

  ## Examples

      iex> create_event(%Claims{field: value}, %{})
      {:ok, %Event{}}

      iex> create_event(%Claims{field: bad_value}, %{})
      {:error, %Ecto.Changeset{}}

  """
  # TODO: unify TdCx.Auth.Claims and TdDd.Auth.Claims
  def create_event(attrs, %{:__struct__ => type, user_id: user_id})
      when type in [TdCx.Auth.Claims, TdDd.Auth.Claims] do
    changeset = Event.changeset(%Event{}, attrs)

    Multi.new()
    |> Multi.insert(:event, changeset)
    |> Multi.update_all(:job_updated_at, &job_updated_at/1, [])
    |> Multi.run(:source_id, fn _, %{event: event} -> {:ok, get_source_id(event)} end)
    |> Multi.run(:external_id, fn _, %{event: event} -> {:ok, get_external_id(event)} end)
    |> Multi.run(:source_external_id, fn _, %{event: event} ->
      {:ok, get_source_external_id(event)}
    end)
    |> Multi.run(:audit, Audit, :job_status_updated, [user_id])
    |> Repo.transaction()
    |> case do
      {:ok, %{event: %Event{} = event}} ->
        IndexWorker.reindex(event.job_id)
        {:ok, event}

      {:error, _, changeset, _} ->
        {:error, changeset}
    end
  end

  defp get_source_id(event) do
    %{job: %{source_id: source_id}} = Repo.preload(event, :job)
    source_id
  end

  defp get_external_id(event) do
    %{job: %{external_id: external_id}} = Repo.preload(event, :job)
    external_id
  end

  defp get_source_external_id(event) do
    %{job: job} = Repo.preload(event, :job)
    %{source: %{external_id: external_id}} = Repo.preload(job, :source)
    external_id
  end

  defp job_updated_at(%{event: %{job_id: job_id, inserted_at: ts}}) do
    Job
    |> where(id: ^job_id)
    |> update(set: [updated_at: ^ts])
  end
end
