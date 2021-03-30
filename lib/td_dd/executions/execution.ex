defmodule TdDd.Executions.Execution do
  @moduledoc """
  Ecto Schema module for executions. An execution represents the relationship
  between an `Strcuture`, a `Group` and a `Profile`. If the execution has completed, it
  will also have an associated `RuleResult`.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias TdDd.DataStructures.DataStructure
  alias TdDd.DataStructures.Profile
  alias TdDd.Executions.Group

  schema "executions" do
    field(:structure_aliases, {:array, :string}, virtual: true)
    belongs_to(:data_structure, DataStructure)
    belongs_to(:group, Group)
    belongs_to(:profile, Profile)
    timestamps(type: :utc_datetime_usec)
  end

  def changeset(%{} = params) do
    changeset(%__MODULE__{}, params)
  end

  def changeset(%__MODULE__{} = struct, %{} = params) do
    struct
    |> cast(params, [:group_id, :data_structure_id, :profile_id, :structure_aliases])
    |> validate_required([:data_structure_id])
    |> foreign_key_constraint(:group_id)
    |> foreign_key_constraint(:data_structure_id)
    |> foreign_key_constraint(:profile_id)
  end
end
