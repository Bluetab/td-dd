defmodule TdDq.Functions.Function do
  @moduledoc """
  Ecto Schema module for functions and operators in data quality implementations
  """

  use Ecto.Schema

  import Ecto.Changeset

  schema "functions" do
    field :name, :string
    field :group, :string
    field :scope, :string
    field :args, {:array, :map}
    timestamps type: :utc_datetime_usec, updated_at: false
  end

  def changeset(%{} = params) do
    changeset(%__MODULE__{}, params)
  end

  def changeset(%__MODULE__{} = struct, %{} = params) do
    struct
    |> cast(params, [:name, :group, :scope, :args])
    |> validate_required([:name, :args])
    |> unique_constraint([:name, :args])
    |> unique_constraint([:name, :args, :group])
    |> unique_constraint([:name, :args, :scope])
    |> unique_constraint([:name, :args, :group, :scope])
  end
end
