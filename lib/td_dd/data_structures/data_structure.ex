defmodule TdDd.DataStructures.DataStructure do
  @moduledoc """
  Ecto Schema module for Data Structures.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias TdCx.Sources.Source
  alias TdDd.DataStructures.DataStructuresTags
  alias TdDd.DataStructures.DataStructureTag
  alias TdDd.DataStructures.DataStructureVersion
  alias TdDd.DataStructures.StructureMetadata
  alias TdDd.DataStructures.StructureNote
  alias TdDd.Grants.Grant
  alias TdDd.Profiles.Profile
  alias TdDd.Systems.System

  @typedoc "A data structure"
  @type t :: %__MODULE__{}

  schema "data_structures" do
    belongs_to(:system, System, on_replace: :update)
    belongs_to(:source, Source)

    has_many(:versions, DataStructureVersion)
    has_many(:metadata_versions, StructureMetadata)
    has_many(:note_versions, StructureNote)
    has_one(:profile, Profile)
    has_many(:data_structures_tags, DataStructuresTags)
    has_many(:grants, Grant)
    many_to_many(:tags, DataStructureTag, join_through: DataStructuresTags)
    has_one(:current_version, DataStructureVersion, where: [deleted_at: nil])
    has_one(:current_metadata, StructureMetadata, where: [deleted_at: nil])

    field(:confidential, :boolean)
    # TODO: remove default?
    field(:domain_ids, {:array, :integer}, default: [])
    field(:external_domain_ids, {:array, :string}, virtual: true)
    field(:external_id, :string)
    field(:last_change_by, :integer)
    field(:row, :integer, virtual: true)
    field(:latest_metadata, :map, virtual: true)
    field(:latest_note, :map, virtual: true)
    field(:domains, :map, virtual: true)
    field(:linked_concepts, :boolean, virtual: true)
    field(:search_content, :map, virtual: true)

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(params, last_change_by) do
    changeset(%__MODULE__{}, params, last_change_by)
  end

  def changeset_check_domain_ids(
        %__MODULE__{} = data_structure,
        %{external_domain_ids: external_domain_ids} = params,
        last_change_by
      ) do
    {existing_domain_ids, _inexistent_domain_ids} =
      domains_by_external_ids = get_domains_by_external_ids(external_domain_ids)

    data_structure
    |> cast(params, [:confidential, :external_domain_ids])
    |> validate_change(
      :external_domain_ids,
      fn _, _domain_ids ->
        case domains_by_external_ids do
          {[], []} ->
            [external_domain_ids: "must be a non-empty list"]

          {[_ | _], []} ->
            []

          {_existing, inexisting} ->
            [
              external_domain_ids:
                {"must exist: %{inexisting}", [inexisting: inexisting |> Enum.intersperse(", ")]}
            ]
        end
      end
    )
    |> put_domain_ids(existing_domain_ids)
    |> unique_domain_ids()
    |> put_audit(last_change_by)
  end

  defp put_domain_ids(changeset, domain_ids) do
    put_change(changeset, :domain_ids, domain_ids)
  end

  def changeset(%__MODULE__{} = data_structure, params, last_change_by)
      when is_integer(last_change_by) do
    data_structure
    |> cast(params, [:confidential, :domain_ids])
    |> validate_change(:domain_ids, fn
      _, [_ | _] -> []
      _, _ -> [domain_ids: "must be a non-empty list"]
    end)
    |> unique_domain_ids()
    |> put_audit(last_change_by)
  end

  def get_domains_by_external_ids(external_domain_ids) do
    Enum.reduce(
      external_domain_ids,
      {[], []},
      fn external_domain_id, {acc_existing, acc_inexisting} ->
        case TdCache.TaxonomyCache.get_by_external_id(external_domain_id) do
          %{id: domain_id} -> {[domain_id | acc_existing], acc_inexisting}
          nil -> {acc_existing, [external_domain_id | acc_inexisting]}
        end
      end
    )
  end

  defp put_audit(%{changes: changes} = changeset, _last_change_by)
       when map_size(changes) == 0 do
    changeset
  end

  defp put_audit(changeset, last_change_by) do
    force_change(changeset, :last_change_by, last_change_by)
  end

  defp unique_domain_ids(changeset) do
    update_change(changeset, :domain_ids, fn domain_ids ->
      domain_ids
      |> Enum.sort()
      |> Enum.uniq()
    end)
  end
end
