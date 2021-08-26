defmodule TdDd.DataStructures.DataStructureTypes do
  @moduledoc """
  The DataStructureTypes context.
  """
  import Ecto.Query

  alias TdCache.TemplateCache
  alias TdDd.DataStructures.DataStructureType
  alias TdDd.DataStructures.DataStructureVersion
  alias TdDd.DataStructures.StructureMetadata
  alias TdDd.Repo

  @doc """
  Returns the list of `DataStructureType` structs.
  """
  def list_data_structure_types do
    data_structure_types_query()
    |> Repo.all()
    |> Enum.map(&enrich_template/1)
  end

  @doc """
  Gets a single `DataStructureType` by id.

  Raises `Ecto.NoResultsError` if the Data structure type does not exist.
  """
  def get!(id) do
    data_structure_types_query()
    |> Repo.get!(id)
    |> enrich_template()
  end

  @doc """
  Gets a single `DataStructureType` by specified clauses.

  Returns nil if no result was found. Raises if more than one entry.
  """
  def get_by(clauses) do
    data_structure_types_query()
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

  defp data_structure_types_query do
    sq = metadata_fields_query()

    DataStructureType
    |> join(:left, [dst], t in subquery(sq), on: t.type == dst.name)
    |> select_merge([dst, t], %{metadata_fields: t.fields})
  end

  defp metadata_fields_query do
    sq = subquery(mutable_metadata_fields_query())

    DataStructureVersion
    |> where([dsv], is_nil(dsv.deleted_at))
    |> select([dsv], %{type: dsv.type, field: fragment("jsonb_object_keys(?)", dsv.metadata)})
    |> distinct(true)
    |> union(^sq)
    |> subquery()
    |> select([t], %{type: t.type, fields: fragment("array_agg(?)", t.field)})
    |> group_by([t], t.type)
  end

  defp mutable_metadata_fields_query do
    DataStructureVersion
    |> where([dsv], is_nil(dsv.deleted_at))
    |> join(:inner, [dsv], sm in StructureMetadata,
      on: sm.data_structure_id == dsv.data_structure_id and is_nil(sm.deleted_at)
    )
    |> select([dsv, sm], %{type: dsv.type, field: fragment("jsonb_object_keys(?)", sm.fields)})
    |> distinct(true)
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
