defmodule TdDd.DataStructures.DataStructureTypes do
  @moduledoc """
  The DataStructureTypes context.
  """
  import Ecto.Query

  alias TdCache.TemplateCache
  alias TdDd.DataStructures.DataStructureType
  alias TdDd.DataStructures.DataStructureVersion
  alias TdDd.DataStructures.MetadataField
  alias TdDd.DataStructures.StructureMetadata
  alias TdDd.Repo

  @typep clauses :: map() | Keyword.t()

  defdelegate authorize(action, user, params), to: __MODULE__.Policy

  @doc """
  Returns the list of `DataStructureType` structs.
  """
  def list_data_structure_types(opts \\ []) do
    preloads = Keyword.get(opts, :preload, [])

    DataStructureType
    |> preload(^preloads)
    |> Repo.all()
    |> Enum.map(&enrich_template/1)
  end

  @doc """
  Gets a single `DataStructureType` by id.

  Raises `Ecto.NoResultsError` if the Data structure type does not exist.
  """
  def get!(id, opts \\ []) do
    preloads = Keyword.get(opts, :preload, :metadata_fields)

    DataStructureType
    |> preload(^preloads)
    |> Repo.get!(id)
    |> enrich_template()
  end

  @doc """
  Gets a single `DataStructureType` by specified clauses.

  Returns nil if no result was found. Raises if more than one entry.
  """
  def get_by(clauses) do
    DataStructureType
    |> preload(:metadata_fields)
    |> Repo.get_by(clauses)
    |> enrich_template()
  end

  def update_data_structure_type(%DataStructureType{} = data_structure_type, params) do
    data_structure_type
    |> Repo.preload(:metadata_fields)
    |> DataStructureType.changeset(params)
    |> Repo.update()
  end

  @spec data_structure_type_fields_query(clauses(), DateTime.t()) :: Ecto.Queryable.t()
  defp data_structure_type_fields_query(clauses, ts) do
    sq = metadata_fields_query(clauses)

    DataStructureType
    |> join(:inner, [dst], f in subquery(sq), on: f.type == dst.name)
    |> select([dst, f], %{
      data_structure_type_id: dst.id,
      name: f.field,
      inserted_at: type(^ts, :utc_datetime_usec),
      updated_at: type(^ts, :utc_datetime_usec)
    })
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
  end

  @spec mutable_metadata_fields_query(clauses()) :: Ecto.Queryable.t()
  defp mutable_metadata_fields_query(clauses) do
    query = join(StructureMetadata, :inner, [sm], dsv in assoc(sm, :current_version))

    clauses
    |> Enum.reduce(query, fn
      {:deleted, false}, q -> where(q, [sm], is_nil(sm.deleted_at))
      {:since, since}, q -> where(q, [sm], sm.updated_at >= ^since)
      {:name, type}, q -> where(q, [_, dsv], dsv.type == ^type)
    end)
    |> select([sm, dsv], %{type: dsv.type, field: fragment("jsonb_object_keys(?)", sm.fields)})
    |> distinct(true)
  end

  @spec data_structure_version_query(clauses()) :: Ecto.Queryable.t()
  defp data_structure_version_query(clauses) do
    clauses
    |> Enum.reduce(DataStructureVersion, fn
      {:deleted, false}, q -> where(q, [dsv], is_nil(dsv.deleted_at))
      {:since, since}, q -> where(q, [dsv], dsv.updated_at >= ^since)
      {:name, type}, q -> where(q, [dsv], dsv.type == ^type)
      _, q -> q
    end)
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

  def refresh_metadata_fields do
    ts = DateTime.utc_now()

    clauses =
      case fields_last_updated() do
        nil -> %{deleted: false}
        since -> %{deleted: false, since: since}
      end

    query = data_structure_type_fields_query(clauses, ts)

    Repo.insert_all(MetadataField, query,
      conflict_target: [:data_structure_type_id, :name],
      on_conflict: [set: [updated_at: ts]]
    )
  end

  def metadata_filters do
    DataStructureType
    |> where([t], not is_nil(t.filters) and t.filters != type(^[], {:array, :string}))
    |> select([t], {t.name, t.filters})
    |> Repo.all()
    |> Map.new()
  end

  defp fields_last_updated do
    MetadataField
    |> select([mf], max(mf.updated_at))
    |> Repo.one()
  end
end
