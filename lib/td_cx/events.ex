defmodule TdCx.Events do
  @moduledoc """
  The Events context.
  """

  alias Ecto.Multi
  alias TdCx.Auth.Claims
  alias TdCx.Events.Event
  alias TdCx.Jobs.Audit
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

      iex> create_event(%{field: value}, %Claims{})
      {:ok, %Event{}}

      iex> create_event(%{field: bad_value}, %Claims{})
      {:error, %Ecto.Changeset{}}

  """
  def create_event(attrs, %Claims{user_id: user_id}) do
    changeset = Event.changeset(%Event{}, attrs)

    Multi.new()
    |> Multi.insert(:event, changeset)
    |> Multi.run(:source_id, fn _, %{event: event} -> {:ok, get_source_id(event)} end)
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
end
