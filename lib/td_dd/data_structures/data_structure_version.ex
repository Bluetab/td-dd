defmodule TdDd.DataStructures.DataStructureVersion do
  @moduledoc """
  Ecto Schema module for Data Structure Versions.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias TdDd.DataStructures
  alias TdDd.DataStructures.DataStructure
  alias TdDd.DataStructures.DataStructureRelation

  schema "data_structure_versions" do
    field(:version, :integer, default: 0)
    field(:class, :string)
    field(:description, :string)
    field(:metadata, :map, default: %{})
    field(:group, :string)
    field(:name, :string)
    field(:type, :string)
    field(:deleted_at, :utc_datetime)
    field(:hash, :binary)
    field(:ghash, :binary)
    field(:lhash, :binary)

    belongs_to(:data_structure, DataStructure)

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

    timestamps(type: :utc_datetime)
  end

  @doc false
  def update_changeset(%__MODULE__{} = data_structure_version, attrs) do
    data_structure_version
    |> cast(attrs, [
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
    changeset
    |> force_change(:updated_at, updated_at)
  end

  defp preserve_timestamp_on_delete(changeset), do: changeset

  def changeset(%{} = params) do
    changeset(%__MODULE__{}, params)
  end

  def changeset(%__MODULE__{} = data_structure_version, attrs) do
    data_structure_version
    |> cast(attrs, [
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
    alias TdCache.StructureTypeCache
    alias TdCache.TaxonomyCache
    alias TdCache.TemplateCache
    alias TdCache.UserCache
    alias TdDd.DataStructures
    alias TdDd.DataStructures.DataStructureVersion
    alias TdDd.DataStructures.PathCache
    alias TdDfLib.Format

    @impl Elasticsearch.Document
    def id(%{id: id}), do: id

    @impl Elasticsearch.Document
    def routing(_), do: false

    @impl Elasticsearch.Document
    def encode(%DataStructureVersion{id: id, data_structure: structure, type: type} = dsv) do
      path = PathCache.path(id)
      parent = PathCache.parent(id)
      path_sort = Enum.join(path, "~")
      domain = TaxonomyCache.get_domain(structure.domain_id) || %{}
      linked_concepts = linked_concepts(dsv)

      structure
      |> Map.take([
        :id,
        :domain_id,
        :external_id,
        :system_id,
        :inserted_at,
        :confidential
      ])
      |> Map.put(:data_fields, get_data_fields(dsv))
      |> Map.put(:path, path)
      |> Map.put(:path_sort, path_sort)
      |> Map.put(:parent, parent)
      |> Map.put(:last_change_by, get_last_change_by(structure))
      |> Map.put(:linked_concepts_count, linked_concepts)
      |> Map.put(:domain_ids, get_domain_ids(structure))
      |> Map.put(:system, get_system(structure))
      |> Map.put(:df_content, format_content(structure, type))
      |> Map.put(:mutable_metadata, get_mutable_metadata(structure))
      |> Map.put_new(:field_type, get_field_type(dsv))
      |> Map.put(:source_alias, get_source_alias(dsv))
      |> Map.put_new(:domain, Map.take(domain, [:id, :name, :external_id]))
      |> Map.merge(
        Map.take(dsv, [
          :class,
          :description,
          :deleted_at,
          :updated_at,
          :group,
          :name,
          :type,
          :metadata,
          :version
        ])
      )
    end

    defp get_system(%DataStructure{system: system}) do
      Map.take(system, [:id, :external_id, :name])
    end

    defp get_data_fields(%DataStructureVersion{} = dsv) do
      dsv
      |> DataStructures.get_field_structures(deleted: false)
      |> Enum.map(&Map.take(&1, [:id, :name]))
    end

    defp get_domain_ids(%DataStructure{domain_id: domain_id}) do
      case domain_id do
        nil -> []
        domain_id -> TaxonomyCache.get_parent_ids(domain_id)
      end
    end

    defp get_last_change_by(%DataStructure{last_change_by: last_change_by}) do
      get_user(last_change_by)
    end

    defp get_user(user_id) do
      case UserCache.get(user_id) do
        {:ok, nil} -> %{}
        {:ok, user} -> user
      end
    end

    defp format_content(%DataStructure{df_content: nil}, _), do: nil

    defp format_content(%DataStructure{df_content: df_content}, _) when map_size(df_content) == 0,
      do: nil

    defp format_content(%DataStructure{df_content: df_content}, type) do
      case StructureTypeCache.get_by_type(type) do
        {:ok, %{template_id: template_id}} ->
          format_content(df_content, TemplateCache.get(template_id))

        _ ->
          %{}
      end
    end

    defp format_content(df_content, {:ok, %{} = template_content}) do
      Format.search_values(df_content, template_content)
    end

    defp format_content(_, _), do: nil

    defp get_field_type(%DataStructureVersion{metadata: metadata}), do: Map.get(metadata, "type")

    defp get_source_alias(%DataStructureVersion{metadata: metadata}),
      do: Map.get(metadata, "alias")

    defp get_mutable_metadata(%DataStructure{id: id}) do
      metadata = DataStructures.get_latest_metadata_version(id, deleted: false) || Map.new()
      Map.get(metadata, :fields, %{})
    end

    defp linked_concepts(dsv) do
      Enum.count(DataStructures.get_structure_links(dsv), &(&1.resource_type == :concept))
    end
  end
end
