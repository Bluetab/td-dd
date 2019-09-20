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
  alias TdDd.DataStructures.Profile
  alias TdDd.Searchable
  alias TdDd.Systems.System
  alias TdDfLib.Format

  @behaviour Searchable

  schema "data_structures" do
    belongs_to(:system, System, on_replace: :update)
    has_many(:versions, DataStructureVersion, on_delete: :delete_all)
    has_one(:profile, Profile, on_delete: :delete_all)

    field(:confidential, :boolean)
    field(:df_content, :map)
    field(:domain_id, :integer)
    field(:external_id, :string)
    field(:last_change_by, :integer)
    field(:ou, :string)

    timestamps(type: :utc_datetime)
  end

  @doc false
  def update_changeset(%DataStructure{} = data_structure, attrs) do
    data_structure
    |> cast(attrs, [
      :confidential,
      :df_content,
      :last_change_by
    ])
  end

  @doc false
  def changeset(%DataStructure{} = data_structure, attrs) do
    data_structure
    |> cast(attrs, [
      :confidential,
      :df_content,
      :domain_id,
      :external_id,
      :last_change_by,
      :ou,
      :system_id
    ])
    |> validate_required([
      :last_change_by,
      :external_id,
      :system_id
    ])
    |> validate_length(:ou, max: 255)
  end

  def search_fields(%DataStructure{} = structure) do
    dsv = DataStructures.get_latest_version(structure, [:data_fields])
    search_fields(structure, dsv)
  end

  defp search_fields(%DataStructure{}, nil = _version), do: %{}

  defp search_fields(
         %DataStructure{last_change_by: last_change_by_id, domain_id: domain_id} = structure,
         %DataStructureVersion{} = dsv
       ) do
    last_change_by =
      case UserCache.get(last_change_by_id) do
        {:ok, nil} -> %{}
        {:ok, user} -> user
      end

    domain_ids = TaxonomyCache.get_parent_ids(domain_id)

    path = DataStructures.get_path(dsv)

    data_fields =
      dsv
      |> Map.get(:data_fields)
      |> Enum.map(&Map.take(&1, [:id, :data_structure_id, :name, :description]))

    system =
      structure
      |> Map.get(:system)
      |> (& &1.__struct__.search_fields(&1)).()

    df_content = format_content(structure, dsv.type)

    structure
    |> Map.take([
      :id,
      :ou,
      :external_id,
      :system_id,
      :inserted_at,
      :updated_at,
      :confidential
    ])
    |> Map.put(:data_fields, data_fields)
    |> Map.put(:path, path)
    |> Map.put(:last_change_by, last_change_by)
    |> Map.put(:domain_id, domain_id)
    |> Map.put(:domain_ids, domain_ids)
    |> Map.put(:system, system)
    |> Map.put(:df_content, df_content)
    |> Map.put_new(:ou, "")
    |> Map.merge(
      Map.take(dsv, [
        :class,
        :description,
        :deleted_at,
        :group,
        :name,
        :type,
        :metadata
      ])
    )
  end

  defp format_content(%DataStructure{df_content: nil}, _), do: nil

  defp format_content(%DataStructure{df_content: df_content}, _) when map_size(df_content) == 0,
    do: nil

  defp format_content(%DataStructure{df_content: df_content}, type) do
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
