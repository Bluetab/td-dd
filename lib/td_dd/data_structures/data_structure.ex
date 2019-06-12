defmodule TdDd.DataStructures.DataStructure do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset
  alias TdDd.DataStructures
  alias TdDd.DataStructures.DataField
  alias TdDd.DataStructures.DataStructure
  alias TdDd.DataStructures.DataStructureVersion
  alias TdDd.Searchable
  alias TdDd.Systems.System
  alias TdPerms.UserCache

  @behaviour Searchable

  @taxonomy_cache Application.get_env(:td_dd, :taxonomy_cache)

  @status %{
    deleted: "deleted"
  }

  schema "data_structures" do
    belongs_to(:system, System, on_replace: :update)
    has_many(:versions, DataStructureVersion, on_delete: :delete_all)

    field(:class, :string)
    field(:confidential, :boolean)
    field(:description, :string)
    field(:df_content, :map)
    field(:domain_id, :integer)
    field(:external_id, :string)
    field(:group, :string)
    field(:last_change_at, :utc_datetime)
    field(:last_change_by, :integer)
    field(:metadata, :map, default: %{})
    field(:name, :string)
    field(:ou, :string)
    field(:type, :string)
    field(:deleted_at, :utc_datetime)

    timestamps(type: :utc_datetime)
  end

  @doc false
  def update_changeset(%DataStructure{} = data_structure, attrs) do
    data_structure
    |> cast(attrs, [
      :confidential,
      :df_content,
      :last_change_at,
      :last_change_by
    ])
  end

  @doc false
  def loader_changeset(%DataStructure{} = data_structure, attrs) do
    audit_attrs = attrs |> Map.take([:last_change_at, :last_change_by])

    changeset =
      data_structure
      |> cast(attrs, [
        :class,
        :confidential,
        :description,
        :domain_id,
        :group,
        :metadata,
        :name,
        :ou,
        :type
      ])

    case changeset.changes do
      m when map_size(m) > 0 -> changeset |> change(audit_attrs)
      _ -> changeset
    end
  end

  @doc false
  def changeset(%DataStructure{} = data_structure, attrs) do
    data_structure
    |> cast(attrs, [
      :class,
      :confidential,
      :description,
      :df_content,
      :domain_id,
      :external_id,
      :group,
      :last_change_at,
      :last_change_by,
      :metadata,
      :name,
      :ou,
      :system_id,
      :type
    ])
    |> validate_required([:group, :last_change_at, :last_change_by, :metadata, :name, :system_id])
    |> validate_length(:class, max: 255)
    |> validate_length(:group, max: 255)
    |> validate_length(:name, max: 255)
    |> validate_length(:ou, max: 255)
    |> validate_length(:type, max: 255)
  end

  def search_fields(%DataStructure{last_change_by: last_change_by_id} = structure) do
    last_change_by =
      case UserCache.get_user(last_change_by_id) do
        nil -> %{}
        user -> user
      end

    domain_id = structure.domain_id

    domain_ids =
      domain_id
      |> @taxonomy_cache.get_parent_ids()

    structure =
      structure
      |> DataStructures.with_latest_fields()
      |> DataStructures.with_latest_path()
      |> fill_items

    system =
      structure
      |> Map.get(:system)
      |> (& &1.__struct__.search_fields(&1)).()

    status =
      case structure.deleted_at do
        nil -> ""
        _del_timestamp -> @status.deleted
      end

    %{
      id: structure.id,
      description: structure.description,
      group: structure.group,
      last_change_at: structure.last_change_at,
      last_change_by: last_change_by,
      name: structure.name,
      ou: structure.ou,
      external_id: structure.external_id,
      domain_id: domain_id,
      domain_ids: domain_ids,
      system: system,
      system_id: structure.system_id,
      type: structure.type,
      inserted_at: structure.inserted_at,
      confidential: structure.confidential,
      df_content: structure.df_content,
      data_fields: Enum.map(structure.data_fields, &DataField.search_fields/1),
      path: structure.path,
      status: status
    }
  end

  defp fill_items(structure) do
    keys_to_fill = [:name, :group, :ou]

    Enum.reduce(keys_to_fill, structure, fn key, acc ->
      case Map.get(acc, key) do
        nil -> Map.put(acc, key, "")
        _ -> acc
      end
    end)
  end

  def index_name(_) do
    "data_structure"
  end
end
