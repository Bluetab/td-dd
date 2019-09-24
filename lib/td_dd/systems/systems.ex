defmodule TdDd.Systems do
  @moduledoc """
  The Systems context.
  """
  import Ecto.Query, warn: false

  alias Ecto.Changeset
  alias TdDd.DataStructures
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

  Raises `Ecto.NoResultsError` if the System does not exist.

  ## Examples

      iex> get_system!(123)
      %System{}

      iex> get_system!(456)
      ** (Ecto.NoResultsError)

  """
  def get_system!(id), do: Repo.get!(System, id)

  @doc """
  Gets a single system by external_id.

  ## Examples

      iex> get_system_by_external_id(ref)
      %System{}

      iex> get_system_by_external_id(ref)
      nil

  """
  def get_system_by_external_id(external_id) do
    System
    |> where([sys], sys.external_id == ^external_id)
    |> Repo.one()
  end

  @doc """
  Gets a single system by name.

  ## Examples

      iex> get_system_by_name(name)
      %System{}

      iex> get_system_by_name(name)
      nil

  """
  def get_system_by_name(name) do
    System
    |> where([sys], sys.name == ^name)
    |> Repo.one()
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

  def get_system_groups(external_id) do
    external_id
    |> get_structure_versions()
    |> get_max_versions()
    |> Enum.map(& &1.group)
    |> Enum.uniq() 
  end

  def delete_structure_versions(external_id, group_name) do 
    external_id
    |> get_structure_versions()
    |> get_max_versions()
    |> Enum.filter(&(&1.group == group_name))
    |> Enum.map(& &1.id)
    |> DataStructures.delete_all()
  end

  defp get_structure_versions(external_id) do
    System
    |> where([sys], sys.external_id == ^external_id)
    |> join(:inner, [sys], ds in assoc(sys, :data_structures))
    |> join(:inner, [_sys, ds], dsv in assoc(ds, :versions))
    |> select([_sys, _ds, dsv], dsv)
    |> Repo.all()
  end

   defp get_max_versions(versions) do
    versions
      |> Enum.group_by(& &1.data_structure_id)
      |> Enum.map(fn {_k, v} -> Enum.max_by(v, & &1.version) end)
  end
end