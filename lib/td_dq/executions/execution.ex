defmodule TdDq.Executions.Execution do
  @moduledoc """
  Ecto Schema module for executions. An execution represents the relationship
  between an `Implementation` and a `Group`. If the execution has completed, it
  will also have an associated `RuleResult`.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias TdDq.Executions.Group
  alias TdDq.Rules.Implementations.Implementation
  alias TdDq.Rules.RuleResult

  schema "executions" do
    field(:structure_aliases, {:array, :string}, virtual: true)
    belongs_to(:group, Group)
    belongs_to(:implementation, Implementation)
    has_one(:rule, through: [:implementation, :rule])
    has_one(:result, RuleResult)
    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  def changeset(%{} = params) do
    changeset(%__MODULE__{}, params)
  end

  def changeset(%__MODULE__{} = struct, %{} = params) do
    struct
    |> cast(params, [:group_id, :implementation_id, :structure_aliases])
    |> validate_required([:implementation_id])
    |> foreign_key_constraint(:group_id)
    |> foreign_key_constraint(:implementation_id)
  end
end
