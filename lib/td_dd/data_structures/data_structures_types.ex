defmodule TdDd.DataStructures.DataStructuresTypes do
  @moduledoc """
  The DataStructures context.
  """

  import Ecto.Query, warn: false

  alias TdCache.StructureTypeCache
  alias TdCache.TemplateCache
  alias TdDd.DataStructures.DataStructureType
  alias TdDd.Repo

  @doc """
  Returns the list of data_structure_types.

  ## Examples

      iex> list_data_structure_types()
      [%DataStructureType{}, ...]

  """
  def list_data_structure_types do
    Repo.all(DataStructureType)
  end

  def enrich_template(%DataStructureType{template_id: template_id} = structure_type) do
    {:ok, template} = TemplateCache.get(template_id)
    Map.put(structure_type, :template, template)
  end

  @doc """
  Gets a single data_structure_type.

  Raises `Ecto.NoResultsError` if the Data structure type does not exist.

  ## Examples

      iex> get_data_structure_type!(123)
      %DataStructureType{}

      iex> get_data_structure_type!(456)
      ** (Ecto.NoResultsError)

  """
  def get_data_structure_type!(id), do: Repo.get!(DataStructureType, id)

  @doc """
  Gets a single data_structure_type by name.

  Raises `Ecto.NoResultsError` if the Data structure type does not exist.

  ## Examples

      iex> get_data_structure_type_by_type("doc")
      %DataStructureType{}

      iex> get_data_structure_type_by_type("non_existing")
      ** (Ecto.NoResultsError)

  """
  def get_data_structure_type_by_type!(type),
    do: Repo.get_by(DataStructureType, structure_type: type)

  @doc """
  Creates a data_structure_type.

  ## Examples

      iex> create_data_structure_type(%{field: value})
      {:ok, %DataStructureType{}}

      iex> create_data_structure_type(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_data_structure_type(params \\ %{}) do
    Repo.transaction(fn ->
      %DataStructureType{}
      |> DataStructureType.changeset(params)
      |> Repo.insert()
      |> on_upsert()
    end)
    |> case do
      {:ok, result} -> result
      {:error, error} -> error
    end
  end

  defp on_upsert(result) do
    with {:ok, data_structure_type} <- result,
         {:ok, _} <- StructureTypeCache.put(data_structure_type) do
      result
    else
      result -> result
    end
  end

  @doc """
  Updates a data_structure_type.

  ## Examples

      iex> update_data_structure_type(data_structure_type, %{field: new_value})
      {:ok, %DataStructureType{}}

      iex> update_data_structure_type(data_structure_type, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_data_structure_type(%DataStructureType{} = data_structure_type, params) do
    Repo.transaction(fn ->
      data_structure_type
      |> DataStructureType.changeset(params)
      |> Repo.update()
      |> on_upsert()
    end)
    |> case do
      {:ok, result} -> result
      {:error, error} -> error
    end
  end

  @doc """
  Deletes a data_structure_type.

  ## Examples

      iex> delete_data_structure_type(data_structure_type)
      {:ok, %DataStructureType{}}

      iex> delete_data_structure_type(data_structure_type)
      {:error, %Ecto.Changeset{}}

  """
  def delete_data_structure_type(%DataStructureType{} = data_structure_type) do
    Repo.transaction(fn ->
      data_structure_type
      |> Repo.delete()
      |> on_delete()
    end)
    |> case do
      {:ok, result} -> result
      {:error, error} -> error
    end
  end

  defp on_delete(result) do
    with {:ok, data_structure_type} <- result,
         {:ok, _} <- StructureTypeCache.delete(Map.get(data_structure_type, :id)) do
      result
    else
      result -> result
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking data_structure_type changes.

  ## Examples

      iex> change_data_structure_type(data_structure_type)
      %Ecto.Changeset{data: %DataStructureType{}}

  """
  def change_data_structure_type(%DataStructureType{} = data_structure_type, params \\ %{}) do
    DataStructureType.changeset(data_structure_type, params)
  end
end
