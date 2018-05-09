defmodule TdDd.DataStructures do
  @moduledoc """
  The DataStructures context.
  """

  import Ecto.Query, warn: false
  alias TdDd.Repo

  alias TdDd.DataStructures.DataStructure

  @doc """
  Returns the list of data_structures.

  ## Examples

      iex> list_data_structures()
      [%DataStructure{}, ...]

  """
  def list_data_structures do
    Repo.all(DataStructure)
  end

  @doc """
  Gets a single data_structure.

  Raises `Ecto.NoResultsError` if the Data structure does not exist.

  ## Examples

      iex> get_data_structure!(123)
      %DataStructure{}

      iex> get_data_structure!(456)
      ** (Ecto.NoResultsError)

  """
  def get_data_structure!(id, opts \\ []) do
    case Keyword.get(opts, :data_fields, false) do
      true -> Repo.one! from ds in DataStructure, preload: [:data_fields]
      false -> Repo.get!(DataStructure, id)
    end

  end

  @doc """
  Creates a data_structure.

  ## Examples

      iex> create_data_structure(%{field: value})
      {:ok, %DataStructure{}}

      iex> create_data_structure(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_data_structure(attrs \\ %{}) do
    %DataStructure{}
    |> DataStructure.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a data_structure.

  ## Examples

      iex> update_data_structure(data_structure, %{field: new_value})
      {:ok, %DataStructure{}}

      iex> update_data_structure(data_structure, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_data_structure(%DataStructure{} = data_structure, attrs) do
    data_structure
    |> DataStructure.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a DataStructure.

  ## Examples

      iex> delete_data_structure(data_structure)
      {:ok, %DataStructure{}}

      iex> delete_data_structure(data_structure)
      {:error, %Ecto.Changeset{}}

  """
  def delete_data_structure(%DataStructure{} = data_structure) do
    Repo.delete(data_structure)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking data_structure changes.

  ## Examples

      iex> change_data_structure(data_structure)
      %Ecto.Changeset{source: %DataStructure{}}

  """
  def change_data_structure(%DataStructure{} = data_structure) do
    DataStructure.changeset(data_structure, %{})
  end

  alias TdDd.DataStructures.DataField

  @doc """
  Returns the list of data_fields.

  ## Examples

      iex> list_data_fields()
      [%DataField{}, ...]

  """
  def list_data_fields do
    Repo.all(DataField)
  end

  @doc """
  Returns the list of data_structure fields .

  ## Examples

      iex> list_data_structure_fields()
      [%DataField{}, ...]

  """
  def list_data_structure_fields(data_structure_id) do
    Repo.all from f in DataField, where: f.data_structure_id == ^data_structure_id
  end

  @doc """
  Gets a single data_field.

  Raises `Ecto.NoResultsError` if the Data field does not exist.

  ## Examples

      iex> get_data_field!(123)
      %DataField{}

      iex> get_data_field!(456)
      ** (Ecto.NoResultsError)

  """
  def get_data_field!(id), do: Repo.get!(DataField, id)

  @doc """
  Creates a data_field.

  ## Examples

      iex> create_data_field(%{field: value})
      {:ok, %DataField{}}

      iex> create_data_field(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_data_field(attrs \\ %{}) do
    %DataField{}
    |> DataField.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a data_field.

  ## Examples

      iex> update_data_field(data_field, %{field: new_value})
      {:ok, %DataField{}}

      iex> update_data_field(data_field, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_data_field(%DataField{} = data_field, attrs) do
    data_field
    |> DataField.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a DataField.

  ## Examples

      iex> delete_data_field(data_field)
      {:ok, %DataField{}}

      iex> delete_data_field(data_field)
      {:error, %Ecto.Changeset{}}

  """
  def delete_data_field(%DataField{} = data_field) do
    Repo.delete(data_field)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking data_field changes.

  ## Examples

      iex> change_data_field(data_field)
      %Ecto.Changeset{source: %DataField{}}

  """
  def change_data_field(%DataField{} = data_field) do
    DataField.changeset(data_field, %{})
  end
end
