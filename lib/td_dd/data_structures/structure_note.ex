defmodule TdDd.DataStructures.StructureNote do
  @moduledoc """
  Ecto schema module for structure note
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias TdDd.DataStructures.DataStructure

  schema "structure_notes" do
    field :df_content, :map

    field :status, Ecto.Enum,
      values: [:draft, :pending_approval, :rejected, :published, :versioned, :deprecated]

    field :version, :integer
    belongs_to(:data_structure, DataStructure)

    timestamps()
  end

  @doc false
  def changeset(structure_note, attrs) do
    structure_note
    |> cast(attrs, [:status, :df_content])
    |> validate_required([:status, :df_content])
  end

  @doc false
  def create_changeset(structure_note, data_structure, attrs) do
    structure_note
    |> cast(attrs, [:status, :version, :df_content])
    |> put_assoc(:data_structure, data_structure)
    |> validate_required([:status, :version, :df_content, :data_structure])
    |> unique_constraint([:data_structure, :version])
  end
end
