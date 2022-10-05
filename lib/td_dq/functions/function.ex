defmodule TdDq.Functions.Function do
  @moduledoc """
  Ecto Schema module for functions and operators in data quality implementations
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias TdDq.Functions.Argument

  schema "functions" do
    field :name, :string
    field :return_type, :string
    field :group, :string
    field :scope, :string
    embeds_many :args, Argument
    timestamps type: :utc_datetime_usec, updated_at: false
  end

  def changeset(%{} = params) do
    changeset(%__MODULE__{}, params)
  end

  def changeset(%__MODULE__{} = struct, %{} = params) do
    struct
    |> cast(params, [:name, :return_type, :group, :scope])
    |> cast_embed(:args, with: &Argument.changeset/2, required: true)
    |> validate_required([:name, :return_type])
    |> unique_constraint([:name, :args])
    |> unique_constraint([:name, :args, :group])
    |> unique_constraint([:name, :args, :scope])
    |> unique_constraint([:name, :args, :group, :scope])
  end
end
