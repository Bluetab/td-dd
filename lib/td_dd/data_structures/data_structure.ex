defmodule TdDd.DataStructures.DataStructure do
  @moduledoc """
  Ecto Schema module for Data Structures.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias TdCx.Sources.Source
  alias TdDd.DataStructures.DataStructureVersion
  alias TdDd.DataStructures.Profile
  alias TdDd.DataStructures.StructureMetadata
  alias TdDd.DataStructures.Validation
  alias TdDd.Systems.System
  alias TdDd.Utils.CollectionUtils
  alias TdDfLib.Content

  @audit_fields [:last_change_by]

  @typedoc "A data structure"
  @type t :: %__MODULE__{}

  schema "data_structures" do
    belongs_to(:system, System, on_replace: :update)
    belongs_to(:source, Source)

    has_many(:versions, DataStructureVersion)
    has_many(:metadata_versions, StructureMetadata)
    has_one(:profile, Profile)

    field(:confidential, :boolean)
    field(:df_content, :map)
    field(:domain_id, :integer)
    field(:external_id, :string)
    field(:last_change_by, :integer)
    field(:row, :integer, virtual: true)
    field(:latest_metadata, :map, virtual: true)

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(%{} = params) do
    changeset(%__MODULE__{}, params)
  end

  def changeset(%__MODULE__{} = data_structure, params) do
    data_structure
    |> cast(params, [
      :confidential,
      :df_content,
      :domain_id,
      :external_id,
      :source_id,
      :system_id
    ])
    |> put_audit(params)
    |> validate_required([
      :external_id,
      :last_change_by,
      :system_id
    ])
    |> validate_change(:df_content, Validation.validator(data_structure))
  end

  def update_changeset(%__MODULE__{} = data_structure, params) do
    data_structure
    |> cast(params, [:confidential, :df_content, :domain_id])
    |> put_audit(params)
    |> validate_change(:df_content, Validation.validator(data_structure))
  end

  def merge_changeset(%__MODULE__{df_content: current_content} = data_structure, params) do
    data_structure
    |> cast(params, [:confidential, :df_content])
    |> update_change(:df_content, &Content.merge(&1, current_content))
    |> put_audit(params)
    |> validate_content(data_structure, params)
  end

  defp put_audit(%{changes: changes} = changeset, _params)
       when map_size(changes) == 0 do
    changeset
  end

  defp put_audit(changeset, %{} = params) do
    cast(changeset, params, @audit_fields)
  end

  defp validate_content(
         %{valid?: true, changes: %{df_content: df_content}} = changeset,
         data_structure,
         params
       )
       when is_map(df_content) do
    fields =
      params
      |> CollectionUtils.atomize_keys()
      |> Map.get(:df_content, %{})
      |> Map.keys()

    case Validation.validator(data_structure, df_content, fields) do
      {:error, error} ->
        add_error(changeset, :df_content, "invalid_template", reason: error)

      %{valid?: false, errors: [_ | _] = errors} ->
        add_error(changeset, :df_content, "invalid_content", errors)

      _ ->
        changeset
    end
  end

  defp validate_content(changeset, _data_structure, _params), do: changeset
end
