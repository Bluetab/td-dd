defmodule TdDd.DataStructures.DataStructureType do
  @moduledoc """
  Ecto Schema module for Data Structure Type.
  """
  use Ecto.Schema

  import Ecto.Changeset

  alias TdDd.DataStructures.MetadataField
  alias TdDd.DataStructures.MetadataView

  @type t :: %__MODULE__{}

  schema "data_structure_types" do
    field(:name, :string)
    field(:template_id, :integer)
    field(:translation, :string)
    field(:filters, {:array, :string}, default: [])
    field(:template, :map, virtual: true)

    embeds_many(:metadata_views, MetadataView, on_replace: :delete)

    has_many(:metadata_fields, MetadataField)

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(%__MODULE__{} = struct, params) do
    struct
    |> cast(params, [:name, :translation, :template_id, :filters])
    |> validate_required(:name)
    |> cast_embed(:metadata_views, with: &MetadataView.changeset/2)
    |> unique_constraint(:name)
    |> validate_filters()
  end

  defp validate_filters(%{} = changeset) do
    case fetch_change(changeset, :filters) do
      :error ->
        changeset

      _ ->
        valid_values =
          changeset
          |> fetch_field!(:metadata_fields)
          |> Enum.map(& &1.name)

        changeset
        |> validate_subset(:filters, valid_values)
    end
  end
end
