defmodule TdDd.DataStructures.DataStructureType do
  @moduledoc """
  Ecto Schema module for Data Structure Type.
  """
  use Ecto.Schema

  import Ecto.Changeset

  alias TdDd.DataStructures.MetadataView

  @type t :: %__MODULE__{}

  schema "data_structure_types" do
    field(:name, :string)
    field(:template_id, :integer)
    field(:translation, :string)
    field(:template, :map, virtual: true)
    field(:metadata_fields, {:array, :string}, virtual: true)
    embeds_many(:metadata_views, MetadataView, on_replace: :delete)

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(data_structure_type, params) do
    data_structure_type
    |> cast(params, [:name, :translation, :template_id])
    |> validate_required(:name)
    |> cast_embed(:metadata_views, with: &MetadataView.changeset/2)
    |> unique_constraint(:name)
  end
end
