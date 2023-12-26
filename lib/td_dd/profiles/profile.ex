defmodule TdDd.Profiles.Profile do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  alias TdDd.DataStructures.DataStructure
  alias TdDd.Profiles.Count
  alias TdDd.Profiles.Distribution
  alias TdDfLib.Validation

  @value_fields [:max, :min, :most_frequent, :null_count, :patterns, :total_count, :unique_count]

  schema "profiles" do
    field(:max, :string)
    field(:min, :string)
    field(:most_frequent, Distribution)
    field(:null_count, Count)
    field(:patterns, Distribution)
    field(:total_count, Count)
    field(:unique_count, Count)
    field(:value, :map)
    belongs_to(:data_structure, DataStructure)

    timestamps()
  end

  def changeset(%{} = params) do
    changeset(%__MODULE__{}, params)
  end

  def changeset(profile, params) do
    profile
    |> cast(params, [:value, :data_structure_id])
    |> validate_required([:value, :data_structure_id])
    |> validate_change(:value, &Validation.validate_safe/2)
    |> expand_value()
    |> foreign_key_constraint(:data_structure_id)
  end

  defp expand_value(%{valid?: true} = changeset) do
    case fetch_field(changeset, :value) do
      {_, %{} = value} ->
        cast(changeset, value, @value_fields)

      _ ->
        changeset
    end
  end

  defp expand_value(changeset), do: changeset
end
