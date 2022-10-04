defmodule TdDd.Systems do
  @moduledoc """
  The Systems context.
  """

  import Ecto.Query

  alias Ecto.Multi
  alias TdDd.Cache.SystemLoader
  alias TdDd.Repo
  alias TdDd.Systems.Audit
  alias TdDd.Systems.System
  alias Truedat.Auth.Claims

  defdelegate authorize(action, user, params), to: __MODULE__.Policy

  @doc """
  Returns the list of systems.

  ## Examples

      iex> list_systems()
      [%System{}, ...]

  """
  def list_systems do
    Repo.all(System)
  end

  @doc """
  Gets a single system.

  Returns the tuple `{:ok, system}` if the system exists, or `{:error,
  :not_found}` if it doesn't.
  """
  def get_system(id) do
    case Repo.get(System, id) do
      nil -> {:error, :not_found}
      system -> {:ok, system}
    end
  end

  @doc """
  Gets a single system, throwing an exception if not found.
  """
  def get_system!(id, opts \\ []) do
    preloads = Keyword.get(opts, :preload, [])

    System
    |> preload(^preloads)
    |> Repo.get!(id)
  end

  @doc """
  Fetches a single system matching the specified clauses.
  See `Repo.get_by/3`.

  ## Examples

      iex> get_by(external_id: external_id)
      %System{}

      iex> get_by(name: name)
      nil

  """
  def get_by(clauses) do
    Repo.get_by(System, clauses)
  end

  @doc """
  Fetches a single system matching the specified clauses, raising an not found
  exception if not found.
  See `Repo.get_by!/3`.
  """
  def get_by!(clauses) do
    Repo.get_by!(System, clauses)
  end

  @doc """
  Creates a system.

  ## Examples

      iex> create_system(%{field: value}, claims)
      {:ok, %System{}}

      iex> create_system(%{field: bad_value}, claims)
      {:error, %Ecto.Changeset{}}

  """
  def create_system(%{} = params, %Claims{user_id: user_id}) do
    changeset = System.changeset(params)

    Multi.new()
    |> Multi.insert(:system, changeset)
    |> Multi.run(:audit, Audit, :system_created, [changeset, user_id])
    |> Repo.transaction()
    |> on_upsert()
  end

  @doc """
  Updates a system.

  ## Examples

      iex> update_system(system, %{field: new_value}, claims)
      {:ok, %System{}}

      iex> update_system(system, %{field: bad_value}, claims)
      {:error, %Ecto.Changeset{}}

  """
  def update_system(%System{} = system, %{} = params, %Claims{user_id: user_id}) do
    changeset = System.changeset(system, params)

    Multi.new()
    |> Multi.update(:system, changeset)
    |> Multi.run(:audit, Audit, :system_updated, [changeset, user_id])
    |> Repo.transaction()
    |> on_upsert()
  end

  @doc """
  Deletes a System.

  ## Examples

      iex> delete_system(system, claims)
      {:ok, %System{}}

      iex> delete_system(system, claims)
      {:error, %Ecto.Changeset{}}

  """
  def delete_system(%System{} = system, %Claims{user_id: user_id}) do
    Multi.new()
    |> Multi.delete(:system, system)
    |> Multi.run(:audit, Audit, :system_deleted, [user_id])
    |> Repo.transaction()
    |> on_delete()
  end

  def get_system_name_to_id_map do
    list_systems()
    |> Enum.map(&Map.take(&1, [:name, :id]))
    |> Enum.into(%{}, fn %{id: id, name: name} -> {name, id} end)
  end

  defp on_upsert(result) do
    with {:ok, %{system: system}} <- result do
      SystemLoader.refresh(system.id)
      result
    end
  end

  defp on_delete(res) do
    with {:ok, %{system: %{id: id}}} <- res do
      SystemLoader.delete(id)
      res
    end
  end
end
