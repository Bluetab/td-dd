defmodule TdDd.DataStructures.DataStructure do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset
  alias TdDd.DataStructures
  alias TdDd.DataStructures.DataField
  alias TdDd.DataStructures.DataStructure
  alias TdDd.DataStructures.DataStructureVersion
  alias TdDd.DataStructures.System
  alias TdDd.Searchable
  alias TdPerms.UserCache

  @behaviour Searchable

  @taxonomy_cache Application.get_env(:td_dd, :taxonomy_cache)

  @data_structure_modifiable_fields Application.get_env(:td_dd, :metadata)[
                                      :data_structure_modifiable_fields
                                    ]
                                    |> Enum.map(&String.to_atom/1)

  schema "data_structures" do
    field(:description, :string)
    field(:domain_id, :integer)
    field(:group, :string)
    field(:last_change_at, :utc_datetime)
    field(:last_change_by, :integer)
    field(:name, :string)
    field(:type, :string)
    field(:ou, :string)
    has_many(:versions, DataStructureVersion, on_delete: :delete_all)
    field(:metadata, :map, default: %{})
    field(:df_name, :string)
    field(:df_content, :map)
    field(:confidential, :boolean)
    field(:external_id, :string)
    belongs_to(:system, System, on_replace: :update)

    timestamps(type: :utc_datetime)
  end

  @doc false
  def update_changeset(%DataStructure{} = data_structure, attrs) do
    data_structure
    |> cast(attrs, [:last_change_at, :last_change_by] ++ @data_structure_modifiable_fields)
  end

  @doc false
  def loader_changeset(%DataStructure{} = data_structure, attrs) do
    changeset = data_structure |> cast(attrs, @data_structure_modifiable_fields)

    case changeset.changes do
      %{} -> changeset
      _ -> update_changeset(data_structure, attrs)
    end
  end

  @doc false
  def changeset(%DataStructure{} = data_structure, attrs) do
    data_structure
    |> cast(attrs, [
      :external_id,
      :group,
      :name,
      :domain_id,
      :description,
      :last_change_at,
      :last_change_by,
      :type,
      :ou,
      :metadata,
      :confidential,
      :df_name,
      :df_content,
      :system_id
    ])
    |> validate_required([:group, :name, :last_change_at, :last_change_by, :metadata, :system_id])
    |> validate_length(:group, max: 255)
    |> validate_length(:name, max: 255)
    |> validate_length(:type, max: 255)
    |> validate_length(:ou, max: 255)
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
      |> fill_items

    system = 
      structure 
      |> Map.get(:system)
      |> get_system_search_value()

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
      df_name: structure.df_name,
      df_content: structure.df_content,
      data_fields: Enum.map(structure.data_fields, &DataField.search_fields/1)
    }
  end

  defp fill_items(structure) do
    keys_to_fill = [:name, :group, :ou, :system]

    Enum.reduce(keys_to_fill, structure, fn key, acc ->
      case Map.get(acc, key) do
        nil -> Map.put(acc, key, "")
        _ -> acc
      end
    end)
  end

  defp get_system_search_value(system) when is_binary(system), do: system

  defp get_system_search_value(system) do
    Map.take(system, [:id, :name, :external_ref])
  end

  def index_name(_) do
    "data_structure"
  end
end
