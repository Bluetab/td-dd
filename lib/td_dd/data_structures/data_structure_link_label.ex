defmodule TdDd.DataStructures.DataStructureLinkLabel do
  @moduledoc """
  Ecto Schema module for Data Structure Links
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias TdDd.DataStructures.DataStructureLink
  alias TdDd.DataStructures.Label

  @primary_key false
  schema "data_structure_links_labels" do
    belongs_to :data_structure_link, DataStructureLink, primary_key: true
    belongs_to :label, Label, primary_key: true
  end

  def changeset(%{} = params) do
    changeset(%__MODULE__{}, params)
  end

  def changeset(%__MODULE__{} = data_structure_link, params) do
    data_structure_link
    |> cast(params, [:data_structure_link_id, :label_id])
    |> foreign_key_constraint(:data_structure_link_id)
    |> foreign_key_constraint(:target_label_id)
  end
end
