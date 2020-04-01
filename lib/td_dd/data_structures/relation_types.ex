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

  def get_default do
    Repo.get_by(RelationType, name: "default")
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

  def with_relation_types(records) do
    default_relation_type = get_default()

    name_to_id_map =
      list_relation_types()
      |> Map.new(fn %{id: id, name: name} -> {name, id} end)

    with_relation_types(records, default_relation_type, name_to_id_map)
  end

  def with_relation_types({structures, relations}, default_relation_type, name_to_id_map) do
    relation_records = with_relation_types(relations, default_relation_type, name_to_id_map)

    {structures, relation_records}
  end

  def with_relation_types(relation_records, default_relation_type, name_to_id_map)
      when is_list(relation_records) do
    relation_records
    |> Enum.map(&{&1, get_relation_type(&1, name_to_id_map, default_relation_type)})
    |> Enum.map(fn {rel, {type, name}} ->
      rel
      |> Map.put(:relation_type_id, type)
      |> Map.put(:relation_type_name, name)
    end)
  end

  def with_relation_types(relation_records, _, _), do: relation_records

  defp get_relation_type(%{relation_type_name: ""}, _, default), do: {default.id, default.name}

  defp get_relation_type(%{relation_type_name: relation_type_name}, id_maps, _) do
    {Map.get(id_maps, relation_type_name), relation_type_name}
  end

  defp get_relation_type(_, _, default), do: {default.id, default.name}
end
