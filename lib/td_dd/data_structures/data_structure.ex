defmodule TdDd.DataStructures.DataStructure do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  alias TdCache.TaxonomyCache
  alias TdCache.TemplateCache
  alias TdCache.UserCache
  alias TdDd.DataStructures
  alias TdDd.DataStructures.DataStructure
  alias TdDd.DataStructures.DataStructureVersion
  alias TdDd.Searchable
  alias TdDd.Systems.System
  alias TdDfLib.Format

  @behaviour Searchable

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
      :last_change_by,
      :deleted_at
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

  def search_fields(
        %DataStructure{last_change_by: last_change_by_id, domain_id: domain_id} = structure
      ) do
    last_change_by =
      case UserCache.get(last_change_by_id) do
        {:ok, nil} -> %{}
        {:ok, user} -> user
      end

    domain_ids = TaxonomyCache.get_parent_ids(domain_id)

    dsv = DataStructures.get_latest_version(structure)
    path = DataStructures.get_path(dsv)

    data_fields =
      dsv
      |> DataStructures.get_field_structures(deleted: false)
      |> Enum.map(&Map.take(&1, [:id, :name, :description]))

    structure =
      %{name: "", group: "", ou: ""}
      |> Map.merge(structure)

    system =
      structure
      |> Map.get(:system)
      |> (& &1.__struct__.search_fields(&1)).()

    status =
      case structure.deleted_at do
        nil -> ""
        _deleted_at -> @status.deleted
      end

    df_content = format_content(structure)

    structure
    |> Map.take([
      :id,
      :description,
      :group,
      :last_change_at,
      :name,
      :ou,
      :external_id,
      :system_id,
      :type,
      :inserted_at,
      :confidential,
      :class
    ])
    |> Map.put(:data_fields, data_fields)
    |> Map.put(:path, path)
    |> Map.put(:last_change_by, last_change_by)
    |> Map.put(:domain_id, domain_id)
    |> Map.put(:domain_ids, domain_ids)
    |> Map.put(:system, system)
    |> Map.put(:status, status)
    |> Map.put(:df_content, df_content)
  end

  defp format_content(%DataStructure{df_content: nil}), do: nil

  defp format_content(%DataStructure{df_content: df_content}) when map_size(df_content) == 0,
    do: nil

  defp format_content(%DataStructure{df_content: df_content, type: type}) do
    format_content(df_content, TemplateCache.get_by_name!(type))
  end

  defp format_content(df_content, %{} = template_content) do
    df_content |> Format.search_values(template_content)
  end

  defp format_content(_, _), do: nil

  def index_name(_) do
    "data_structure"
  end
end
