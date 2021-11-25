defmodule TdDd.DataStructures.DataStructureTypes do
  @moduledoc """
  The DataStructureTypes context.
  """
  import Ecto.Query

  alias TdCache.TemplateCache
  alias TdDd.DataStructures.DataStructureType
  alias TdDd.DataStructures.DataStructureVersion
  alias TdDd.Repo

  @typep clauses :: map() | Keyword.t()

  @doc """
  Returns the list of `DataStructureType` structs.
  """
  def list_data_structure_types do
    data_structure_types_query()
    |> Repo.all()
    |> Enum.map(&enrich_template/1)
  end

  def list_data_structure_types(:lite) do
    DataStructureType
    |> Repo.all()
    |> Enum.map(&enrich_template/1)
    |> Enum.map(fn structure_type -> Map.delete(structure_type, :metadata_fields) end)
  end

  @doc """
  Gets a single `DataStructureType` by id.

  Raises `Ecto.NoResultsError` if the Data structure type does not exist.
  """
  def get!(id) do
    %{name: name} = Repo.get!(DataStructureType, id)

    data_structure_types_query(name: name)
    |> Repo.get!(id)
    |> enrich_template()
  end

  @doc """
  Gets a single `DataStructureType` by specified clauses.

  Returns nil if no result was found. Raises if more than one entry.
  """
  def get_by(clauses) do
    data_structure_types_query(clauses)
    |> Repo.get_by(clauses)
    |> enrich_template()
  end

  @doc """
  Updates a `DataStructureType`.

  ## Examples

      iex> update_data_structure_type(data_structure_type, %{field: new_value})
      {:ok, %DataStructureType{}}

      iex> update_data_structure_type(data_structure_type, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_data_structure_type(%DataStructureType{} = data_structure_type, params) do
    data_structure_type
    |> DataStructureType.changeset(params)
    |> Repo.update()
  end

  @spec data_structure_types_query(clauses()) :: Ecto.Queryable.t()
  defp data_structure_types_query(clauses \\ %{}) do
    sq = metadata_fields_query(clauses)

    DataStructureType
    |> join(:left, [dst], t in subquery(sq), on: t.type == dst.name)
    |> select_merge([dst, t], %{metadata_fields: t.fields})
  end

  @spec metadata_fields_query(clauses()) :: Ecto.Queryable.t()
  defp metadata_fields_query(clauses) do
    sq =
      clauses
      |> mutable_metadata_fields_query()
      |> subquery()

    clauses
    |> data_structure_version_query()
    |> select([dsv], %{type: dsv.type, field: fragment("jsonb_object_keys(?)", dsv.metadata)})
    |> distinct(true)
    |> union(^sq)
    |> subquery()
    |> select([t], %{type: t.type, fields: fragment("array_agg(?)", t.field)})
    |> group_by([t], t.type)
  end

  @spec mutable_metadata_fields_query(clauses()) :: Ecto.Queryable.t()
  defp mutable_metadata_fields_query(clauses) do
    clauses
    |> data_structure_version_query()
    |> join(:inner, [dsv], sm in assoc(dsv, :current_metadata))
    |> select([dsv, sm], %{type: dsv.type, field: fragment("jsonb_object_keys(?)", sm.fields)})
    |> distinct(true)
  end

  @spec data_structure_version_query(clauses()) :: Ecto.Queryable.t()
  defp data_structure_version_query(clauses) do
    clauses
    |> Enum.reduce(DataStructureVersion, fn
      {:name, type}, q -> where(q, [dsv], dsv.type == ^type)
      _, q -> q
    end)
    |> where([dsv], is_nil(dsv.deleted_at))
  end

  @spec enrich_template(DataStructureType.t() | nil) :: DataStructureType.t() | nil
  defp enrich_template(structure_type_or_nil)

  defp enrich_template(%DataStructureType{template_id: template_id} = structure_type)
       when is_integer(template_id) do
    case TemplateCache.get(template_id) do
      {:ok, template} -> %{structure_type | template: template}
      _ -> structure_type
    end
  end

  defp enrich_template(structure_type_or_nil), do: structure_type_or_nil
end
