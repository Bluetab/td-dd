defmodule TdCx.Sources.Events do
  @moduledoc """
  The Sources.Events context.
  """

  import Ecto.Query, warn: false
  alias TdCx.Repo

  alias TdCx.Search.IndexWorker
  alias TdCx.Sources.Events.Event

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

      iex> create_event(%{field: value})
      {:ok, %Event{}}

      iex> create_event(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_event(attrs \\ %{}) do
    %Event{}
    |> Event.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, %Event{} = event} ->
        IndexWorker.reindex(event.job_id)
        {:ok, event}

      error ->
        error
    end
  end

end
