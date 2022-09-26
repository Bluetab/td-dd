defmodule TdDd.DataStructures.RelationTypes do
  @moduledoc """
  The RelationTypes context.
  """

  import Ecto.Query

  alias TdDd.DataStructures.RelationType
  alias TdDd.Repo

  defdelegate authorize(action, user, params), to: __MODULE__.Policy

  def list_relation_types(args \\ %{}) do
    args
    |> relation_type_query()
    |> Repo.all()
  end

  def relation_type_query(args) do
    Enum.reduce(args, RelationType, fn
      {:names, names}, q -> where(q, [rt], rt.name in ^names)
      {:select, :id}, q -> select(q, [rt], rt.id)
    end)
  end

  def get_relation_type!(id), do: Repo.get!(RelationType, id)

  def default_id! do
    RelationType
    |> where(name: "default")
    |> select([t], t.id)
    |> Repo.one!()
  end

  @doc """
  Creates a relation_type.

  ## Examples

      iex> create_relation_type(%{field: value})
      {:ok, %RelationType{}}

      iex> create_relation_type(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_relation_type(params \\ %{}) do
    %RelationType{}
    |> RelationType.changeset(params)
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
  def update_relation_type(%RelationType{} = relation_type, params) do
    relation_type
    |> RelationType.changeset(params)
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
    default_relation_type = Repo.get_by!(RelationType, name: "default")

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
