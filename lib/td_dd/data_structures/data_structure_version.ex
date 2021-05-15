defmodule TdDd.DataStructures.DataStructureVersion do
  @moduledoc """
  Ecto Schema module for Data Structure Versions.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias TdDd.DataStructures.Classification
  alias TdDd.DataStructures.DataStructure
  alias TdDd.DataStructures.DataStructureRelation

  @typedoc "A data structure version"
  @type t :: %__MODULE__{}

  schema "data_structure_versions" do
    field(:version, :integer, default: 0)
    field(:class, :string)
    field(:description, :string)
    field(:metadata, :map, default: %{})
    field(:group, :string)
    field(:name, :string)
    field(:type, :string)
    field(:deleted_at, :utc_datetime_usec)
    field(:hash, :binary)
    field(:ghash, :binary)
    field(:lhash, :binary)
    field(:path, {:array, :map}, virtual: true)
    field(:external_id, :string, virtual: true)
    field(:profile_source, :map, virtual: true)
    field(:classes, :map, virtual: true)
    field(:mutable_metadata, :map, virtual: true)

    belongs_to(:data_structure, DataStructure)

    has_many(:classifications, Classification)
    has_many(:child_relations, DataStructureRelation, foreign_key: :parent_id)
    has_many(:parent_relations, DataStructureRelation, foreign_key: :child_id)

    many_to_many(:children, __MODULE__,
      join_through: DataStructureRelation,
      join_keys: [parent_id: :id, child_id: :id]
    )

    many_to_many(:parents, __MODULE__,
      join_through: DataStructureRelation,
      join_keys: [child_id: :id, parent_id: :id]
    )

    timestamps(type: :utc_datetime_usec)
  end

  def update_changeset(%__MODULE__{} = data_structure_version, params) do
    data_structure_version
    |> cast(params, [
      :class,
      :deleted_at,
      :description,
      :hash,
      :lhash,
      :ghash,
      :metadata,
      :group,
      :name,
      :type,
      :version
    ])
    |> validate_lengths()
    |> preserve_timestamp_on_delete()
  end

  defp preserve_timestamp_on_delete(
         %{changes: %{deleted_at: deleted_at}, data: %{updated_at: updated_at}} = changeset
       )
       when not is_nil(deleted_at) do
    force_change(changeset, :updated_at, updated_at)
  end

  defp preserve_timestamp_on_delete(changeset), do: changeset

  def changeset(%{} = params) do
    changeset(%__MODULE__{}, params)
  end

  def changeset(%__MODULE__{} = data_structure_version, params) do
    data_structure_version
    |> cast(params, [
      :class,
      :data_structure_id,
      :description,
      :group,
      :metadata,
      :name,
      :type,
      :version,
      :lhash,
      :ghash,
      :hash
    ])
    |> validate_required([:data_structure_id, :group, :metadata, :name, :version])
    |> validate_lengths()
  end

  defp validate_lengths(changeset) do
    changeset
    |> validate_length(:class, max: 255)
    |> validate_length(:group, max: 255)
    |> validate_length(:name, max: 255)
    |> validate_length(:type, max: 255)
  end

  defimpl Elasticsearch.Document do
    alias TdDd.DataStructures.DataStructureVersion

    @max_sortable_length 32_766

    @impl Elasticsearch.Document
    def id(%{data_structure_id: id}), do: id

    @impl Elasticsearch.Document
    def routing(_), do: false

    @impl Elasticsearch.Document
    def encode(
          %DataStructureVersion{
            data_structure: %{search_content: content} = data_structure,
            path: path
          } = dsv
        ) do
      # IMPORTANT: Avoid enriching structs one-by-one in this function.
      # Instead, enrichment should be performed as efficiently as possible on
      # chunked data using `TdDd.DataStructures.enriched_structure_versions/1`.
      data_structure
      |> Map.take([
        :id,
        :domain_id,
        :external_id,
        :system_id,
        :inserted_at,
        :confidential,
        :source_id,
        :linked_concepts_count
      ])
      |> Map.put(:path_sort, path_sort(path))
      |> Map.put(:domain_ids, domain_ids(data_structure))
      |> Map.put(:system, system(data_structure))
      |> Map.put(:df_content, content)
      |> Map.put(:with_content, is_map(content) and map_size(content) > 0)
      |> Map.put(:field_type, field_type(dsv))
      |> Map.put(:source_alias, source_alias(dsv))
      |> Map.put(:domain, domain(data_structure))
      |> Map.merge(
        Map.take(dsv, [
          :class,
          :classes,
          :description,
          :deleted_at,
          :updated_at,
          :group,
          :name,
          :path,
          :type,
          :metadata,
          :mutable_metadata,
          :version
        ])
      )
    end

    defp path_sort(nil), do: ""

    defp path_sort(path) when is_list(path) do
      path |> Enum.map(&Map.get(&1, "name", "")) |> Enum.join("~")
    end

    defp domain(%{domain: %{} = domain}), do: Map.take(domain, [:id, :external_id, :name])
    defp domain(_), do: %{}

    defp system(%{system: %{} = system}), do: Map.take(system, [:id, :external_id, :name])

    defp domain_ids(%{domain: %{parent_ids: parent_ids}}), do: parent_ids
    defp domain_ids(_), do: []

    defp field_type(%{metadata: %{"type" => type}})
         when byte_size(type) > @max_sortable_length do
      binary_part(type, 0, @max_sortable_length)
    end

    defp field_type(%{metadata: %{"type" => type}}), do: type
    defp field_type(_), do: nil

    defp source_alias(%{metadata: %{"alias" => value}}), do: value
    defp source_alias(_), do: nil
  end
end
