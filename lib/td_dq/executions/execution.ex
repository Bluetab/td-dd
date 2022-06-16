defmodule TdDq.Executions.Execution do
  @moduledoc """
  Ecto Schema module for executions. An execution represents the relationship
  between an `Implementation` and a `Group`. If the execution has completed, it
  will also have an associated `RuleResult`.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias TdDq.Events.QualityEvent
  alias TdDq.Executions.Group
  alias TdDq.Implementations.Implementation
  alias TdDq.Rules.Rule
  alias TdDq.Rules.RuleResult

  schema "executions" do
    field(:structure_aliases, {:array, :string}, virtual: true)
    belongs_to(:group, Group)
    belongs_to(:implementation, Implementation)
    belongs_to(:result, RuleResult)
    belongs_to(:rule, Rule)
    has_many(:quality_events, QualityEvent)
    timestamps(type: :utc_datetime_usec)
  end

  def changeset(%{} = params) do
    changeset(%__MODULE__{}, params)
  end

  def changeset(%__MODULE__{} = struct, %{} = params) do
    struct
    |> cast(params, [:group_id, :implementation_id, :result_id, :structure_aliases])
    |> validate_required(:implementation_id)
    |> foreign_key_constraint(:group_id)
    |> foreign_key_constraint(:implementation_id)
    |> foreign_key_constraint(:result_id)
    |> cast_assoc(:quality_events, with: &QualityEvent.changeset/2)
  end
end
