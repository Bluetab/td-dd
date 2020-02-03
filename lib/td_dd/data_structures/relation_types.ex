defmodule TdDd.DataStructures.RelationTypes do
  @moduledoc """
  The RelationTypes context.
  """

  import Ecto.Query, warn: false
  alias TdDd.Repo

  alias TdDd.DataStructures.RelationType

  @doc """
  Returns the list of relation_types.

  ## Examples

      iex> list_relation_types()
      [%RelationType{}, ...]

  """
  def list_relation_types do
    Repo.all(RelationType)
  end

  def get_relation_type_name_to_id_map do
    list_relation_types()
    |> Enum.map(&Map.take(&1, [:name, :id]))
    |> Enum.into(%{}, fn %{id: id, name: name} -> {name, id} end)
  end

  @doc """
  Gets a single relation_type.

  Raises `Ecto.NoResultsError` if the Relation type does not exist.

  ## Examples

      iex> get_relation_type!(123)
      %RelationType{}

      iex> get_relation_type!(456)
      ** (Ecto.NoResultsError)

  """
  def get_relation_type!(id), do: Repo.get!(RelationType, id)

  def get_default_relation_type do
    Repo.get_by(RelationType, name: RelationType.default)
  end

  @doc """
  Creates a relation_type.

  ## Examples

      iex> create_relation_type(%{field: value})
      {:ok, %RelationType{}}

      iex> create_relation_type(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_relation_type(attrs \\ %{}) do
    %RelationType{}
    |> RelationType.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a relation_type.

  ## Examples

      iex> update_relation_type(relation_type, %{field: new_value})
      {:ok, %RelationType{}}

      iex> update_relation_type(relation_type, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_relation_type(%RelationType{} = relation_type, attrs) do
    relation_type
    |> RelationType.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a RelationType.

  ## Examples

      iex> delete_relation_type(relation_type)
      {:ok, %RelationType{}}

      iex> delete_relation_type(relation_type)
      {:error, %Ecto.Changeset{}}

  """
  def delete_relation_type(%RelationType{} = relation_type) do
    Repo.delete(relation_type)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking relation_type changes.

  ## Examples

      iex> change_relation_type(relation_type)
      %Ecto.Changeset{source: %RelationType{}}

  """
  def change_relation_type(%RelationType{} = relation_type) do
    RelationType.changeset(relation_type, %{})
  end
end
