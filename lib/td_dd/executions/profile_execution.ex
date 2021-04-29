defmodule TdDd.Executions.ProfileExecution do
  @moduledoc """
  Ecto Schema module for executions. An execution represents the relationship
  between an `Strcuture`, a `Group` and a `Profile`. If the execution has completed, it
  will also have an associated `RuleResult`.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias TdDd.DataStructures.DataStructure
  alias TdDd.DataStructures.Profile
  alias TdDd.Events.ProfileEvent
  alias TdDd.Executions.ProfileGroup

  schema "profile_executions" do
    field(:source_alias, :string, virtual: true)
    belongs_to(:data_structure, DataStructure)
    belongs_to(:profile_group, ProfileGroup)
    belongs_to(:profile, Profile)
    has_many(:profile_events, ProfileEvent)
    timestamps(type: :utc_datetime_usec)
  end

  def changeset(%{} = params) do
    changeset(%__MODULE__{}, params)
  end

  def changeset(%__MODULE__{} = struct, %{} = params) do
    struct
    |> cast(params, [:profile_group_id, :data_structure_id, :profile_id])
    |> validate_required([:data_structure_id])
    |> foreign_key_constraint(:profile_group_id)
    |> foreign_key_constraint(:data_structure_id)
    |> foreign_key_constraint(:profile_id)
    |> cast_assoc(:profile_events, with: &ProfileEvent.changeset/2, required: false)
  end
end
