defmodule TdDd.DataStructures.DataStructureLink do
  @moduledoc """
  Ecto Schema module for Data Structure Links
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias TdDd.DataStructures.DataStructure
  alias TdDd.DataStructures.DataStructureLinkLabel
  alias TdDd.DataStructures.Label

  schema "data_structures_links" do
    belongs_to :source, DataStructure
    belongs_to :target, DataStructure
    field(:source_external_id, :string)
    field(:target_external_id, :string)
    timestamps(type: :utc_datetime_usec)
    field(:label_names, {:array, :string}, virtual: true)

    many_to_many(:labels, Label,
      join_through: DataStructureLinkLabel,
      on_delete: :delete_all,
      on_replace: :delete
    )
  end

  def changeset(%{} = params) do
    changeset(%__MODULE__{}, params)
  end

  def changeset(%__MODULE__{} = data_structure_link, params) do
    data_structure_link
    |> cast(params, [
      :source_id,
      :target_id,
      :source_external_id,
      :target_external_id,
      :label_names
    ])
    |> validate_required([:source_external_id, :target_external_id])
    |> foreign_key_constraint(:source_id)
    |> foreign_key_constraint(:target_id)
  end
end
