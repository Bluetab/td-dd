defmodule TdDd.Systems do
  @moduledoc """
  The Systems context.
  """
  import Ecto.Query, warn: false

  alias TdDd.Repo
  alias TdDd.Systems.System

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

  ## Examples

      iex> get_system(123)
      {:ok, %System{}}

      iex> get_system(456)
      {:error, :not_found}

  """
  def get_system(id) do
    case Repo.get(System, id) do
      nil -> {:error, :not_found}
      system -> {:ok, system}
    end
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
  Creates a system.

  ## Examples

      iex> create_system(%{field: value})
      {:ok, %System{}}

      iex> create_system(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_system(attrs \\ %{}) do
    %System{}
    |> System.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a system.

  ## Examples

      iex> update_system(system, %{field: new_value})
      {:ok, %System{}}

      iex> update_system(system, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_system(%System{} = system, attrs) do
    system
    |> System.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a System.

  ## Examples

      iex> delete_system(system)
      {:ok, %System{}}

      iex> delete_system(system)
      {:error, %Ecto.Changeset{}}

  """
  def delete_system(%System{} = system) do
    Repo.delete(system)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking system changes.

  ## Examples

      iex> change_system(system)
      %Ecto.Changeset{source: %System{}}

  """
  def change_system(%System{} = system) do
    System.changeset(system, %{})
  end

  def diff(%System{} = old, %System{} = new) do
    [:external_id, :name]
    |> Enum.map(fn field -> {field, Map.get(old, field), Map.get(new, field)} end)
    |> Enum.reject(fn {_, old, new} -> old == new end)
    |> Enum.map(fn {field, _, new} -> {field, new} end)
    |> Map.new()
  end

  def get_system_name_to_id_map do
    list_systems()
    |> Enum.map(&Map.take(&1, [:name, :id]))
    |> Enum.into(%{}, fn %{id: id, name: name} -> {name, id} end)
  end
end
