defmodule TdDd.DataStructures.DataStructureVersions.RecordEmbedding do
  @moduledoc """
  Stores data structure version embeddings
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias TdDd.DataStructures.DataStructureVersion
  alias TdDd.Helpers

  @derive Jason.Encoder
  schema "record_embeddings" do
    field :collection, :string
    field :dims, :integer
    field :embedding, {:array, :float}

    belongs_to :data_structure_version, DataStructureVersion, on_replace: :update

    timestamps(type: :utc_datetime_usec)
  end

  @doc false
  def changeset(record_embedding, attrs) do
    record_embedding
    |> cast(attrs, [:data_structure_version_id, :collection, :dims, :embedding])
    |> validate_required([:data_structure_version_id, :collection, :dims, :embedding])
  end

  def coerce(%{"id" => id, "inserted_at" => inserted_at, "updated_at" => updated_at} = attrs) do
    inserted_at = Helpers.binary_to_utc_date_time(inserted_at)
    updated_at = Helpers.binary_to_utc_date_time(updated_at)

    %__MODULE__{}
    |> changeset(attrs)
    |> apply_changes()
    |> Map.put(:id, id)
    |> Map.put(:inserted_at, inserted_at)
    |> Map.put(:updated_at, updated_at)
  end
end
