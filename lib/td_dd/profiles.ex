defmodule TdDd.Profiles do
  @moduledoc """
  The DataStructure Profiles context.
  """

  import Ecto.Query

  alias Ecto.Multi
  alias TdCore.Search.IndexWorker
  alias TdDd.DataStructures
  alias TdDd.Executions
  alias TdDd.Executions.ProfileEvents
  alias TdDd.Profiles.Profile
  alias TdDd.Repo

  defdelegate authorize(action, user, params), to: __MODULE__.Policy

  @doc """
  Returns the list of profiles.

  ## Examples

      iex> list_profiles()
      [%Profile{}, ...]

  """
  def list_profiles(params \\ %{}) do
    params
    |> Enum.reduce(Profile, fn
      {"limit", size}, query -> limit(query, ^size)
      {"offset", size}, query -> offset(query, ^size)
      {"since", ts}, query -> where(query, [p], p.updated_at >= ^ts)
      _, query -> query
    end)
    |> Repo.all()
  end

  @doc """
  Gets a single profile.

  Raises `Ecto.NoResultsError` if the Profile does not exist.

  ## Examples

      iex> get_profile!(123)
      %Profile{}

      iex> get_profile!(456)
      ** (Ecto.NoResultsError)

  """
  def get_profile!(id), do: Repo.get!(Profile, id)

  @doc """
  Creates or updates a profile.

  ## Examples

      iex> create_or_update_profile(%{field: value})
      {:ok, %Profile{}}

      iex> create_or_update_profile(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_or_update_profile(params) do
    changeset = Profile.changeset(params)

    Multi.new()
    |> Multi.run(:profile, fn _, _ -> do_create_or_update_profile(changeset) end)
    |> Multi.run(:executions, fn _, changes -> update_executions(changes) end)
    |> Multi.run(:events, fn _, %{executions: executions} ->
      {_, events} = ProfileEvents.complete(executions)
      {:ok, events}
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{profile: profile}} ->
        on_upsert({:ok, profile})

      {:error, _, changeset, _} ->
        {:error, changeset}
    end
  end

  @doc """
  Creates a profile.

  ## Examples

      iex> create_profile(%{field: value})
      {:ok, %Profile{}}

      iex> create_profile(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_profile(params) do
    %Profile{}
    |> Profile.changeset(params)
    |> Repo.insert()
    |> on_upsert()
  end

  @doc """
  Updates a profile.

  ## Examples

      iex> update_profile(profile, %{field: new_value})
      {:ok, %Profile{}}

      iex> update_profile(profile, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_profile(%Profile{} = profile, params) do
    profile
    |> Profile.changeset(params)
    |> Repo.update()
    |> on_upsert()
  end

  defp do_create_or_update_profile(%{changes: %{data_structure_id: id} = changes} = changeset) do
    case Repo.get_by(Profile, data_structure_id: id) do
      nil -> Repo.insert(changeset)
      %Profile{} = profile -> Repo.update(Profile.changeset(profile, changes))
    end
  end

  defp update_executions(%{profile: %{id: profile_id, data_structure_id: structure_id}}) do
    {_, executions} = Executions.update_all(structure_id, profile_id)
    {:ok, executions}
  end

  def expand_profile_values do
    Profile
    |> Repo.all()
    |> Enum.map(fn %{value: value} = profile -> Profile.changeset(profile, %{value: value}) end)
    |> Enum.filter(& &1.valid?)
    |> Enum.map(&Repo.update/1)
  end

  defp on_upsert({:ok, %Profile{data_structure_id: data_structure_id}} = reply) do
    version = DataStructures.get_latest_version(data_structure_id, [:parents])

    case version do
      %{parents: [_ | _] = parents} ->
        data_structure_ids = Enum.map(parents, & &1.data_structure_id) ++ [data_structure_id]
        IndexWorker.reindex(:structures, data_structure_ids)

      _ ->
        IndexWorker.reindex(:structures, data_structure_id)
    end

    reply
  end

  defp on_upsert(reply), do: reply
end
