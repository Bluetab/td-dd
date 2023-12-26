defmodule TdDq.Executions.Group do
  @moduledoc """
  Ecto Schema module for execution groups. An `ExecutionGroup` consists of a
  group of rule implementations.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias TdDfLib.Validation
  alias TdDq.Executions.Execution
  alias TdDq.Implementations.Implementation

  schema "execution_groups" do
    field(:filters, :map, virtual: true)
    field(:created_by_id, :integer)
    field(:df_content, :map)
    has_many(:executions, Execution)
    many_to_many(:implementations, Implementation, join_through: Execution)
    timestamps(updated_at: false)
  end

  def changeset(%{} = params) do
    changeset(%__MODULE__{}, params)
  end

  def changeset(%__MODULE__{} = struct, %{} = params) do
    struct
    |> cast(params, [:created_by_id, :filters, :df_content])
    |> validate_required(:created_by_id)
    |> cast_assoc(:executions, with: &Execution.changeset/2, required: true)
    |> validate_change(:df_content, &Validation.validate_safe/2)
  end
end
