defmodule TdDd.DataStructures.DataStructureVersion do
  @moduledoc """
  Ecto Schema module for Data Structure Versions.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias TdDd.DataStructures.Classification
  alias TdDd.DataStructures.DataStructure
  alias TdDd.DataStructures.DataStructureRelation
  alias TdDd.DataStructures.DataStructureType
  import Ecto.Query

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
    field(:path, {:array, :map}, virtual: true, default: [])
    field(:external_id, :string, virtual: true)
    field(:profile_source, :map, virtual: true)
    field(:classes, :map, virtual: true)
    field(:mutable_metadata, :map, virtual: true)
    field(:note, :map, virtual: true)
    field(:grants, {:array, :map}, virtual: true)
    field(:grant, :map, virtual: true)
    field(:with_profiling, :boolean, virtual: true)
    field(:_filters, :map, virtual: true)
    field(:tag_names, {:array, :string}, virtual: true)

    belongs_to(:data_structure, DataStructure)

    belongs_to(:structure_type, DataStructureType,
      foreign_key: :type,
      references: :name,
      define_field: false
    )

    has_many(:classifications, Classification)
    has_many(:child_relations, DataStructureRelation, foreign_key: :parent_id)
    has_many(:parent_relations, DataStructureRelation, foreign_key: :child_id)
    has_one(:current_metadata, through: [:data_structure, :current_metadata])
    has_one(:published_note, through: [:data_structure, :published_note])

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

  def with_data_structure do
    from __MODULE__, preload: :data_structure
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
            data_structure:
              %{alias: alias_name, search_content: content, domain_ids: _domain_ids} =
                data_structure,
            path: path,
            tag_names: tags
          } = dsv
        ) do
      # IMPORTANT: Avoid enriching structs one-by-one in this function.
      # Instead, enrichment should be performed as efficiently as possible on
      # chunked data using `TdDd.DataStructures.enriched_structure_versions/1`.
      name_path = Enum.map(path, & &1["name"])

      data_structure
      |> Map.take([
        :confidential,
        :domain_ids,
        :external_id,
        :id,
        :inserted_at,
        :linked_concepts,
        :source_id,
        :system_id
      ])
      |> Map.put(:note, content)
      |> Map.put(:domain, first_domain(data_structure))
      |> Map.put(:field_type, field_type(dsv))
      |> Map.put(:path_sort, path_sort(name_path))
      |> Map.put(:path, name_path)
      |> Map.put(:source_alias, source_alias(dsv))
      |> Map.put(:system, system(data_structure))
      |> Map.put(:with_content, is_map(content) and map_size(content) > 0)
      |> Map.put(:tags, tags)
      |> Map.merge(
        Map.take(dsv, [
          :_filters,
          :class,
          :classes,
          :data_structure_id,
          :deleted_at,
          :description,
          :group,
          :metadata,
          :mutable_metadata,
          :name,
          :type,
          :updated_at,
          :version,
          :with_profiling
        ])
      )
      |> maybe_put_alias(alias_name)
    end

    defp maybe_put_alias(map, nil), do: map

    defp maybe_put_alias(%{name: original_name} = map, alias_name) do
      map
      |> Map.put(:name, alias_name)
      |> Map.put(:original_name, original_name)
    end

    defp path_sort(name_path) when is_list(name_path) do
      Enum.join(name_path, "~")
    end

    defp first_domain(%{domains: [domain | _]}),
      do: Map.take(domain, [:id, :external_id, :name])

    defp first_domain(_), do: nil

    defp system(%{system: %{} = system}), do: Map.take(system, [:id, :external_id, :name])

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
