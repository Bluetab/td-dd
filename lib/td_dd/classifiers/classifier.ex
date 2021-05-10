defmodule TdDd.Classifiers.Classifier do
  @moduledoc """
  Ecto Schema module for classifiers.
  """

  use Ecto.Schema

  alias TdDd.Classifiers.Filter
  alias TdDd.Classifiers.Rule
  alias TdDd.Systems.System

  import Ecto.Changeset

  @typedoc "A classifier"
  @type t :: %__MODULE__{}
  @typep changeset :: Ecto.Changeset.t()

  schema "classifiers" do
    field :name, :string
    belongs_to :system, System
    has_many :filters, Filter
    has_many :rules, Rule
    has_many :classifications, through: [:rules, :classifications]
    timestamps(type: :utc_datetime_usec)
  end

  @spec changeset(map) :: changeset
  def changeset(%{} = params) do
    changeset(%__MODULE__{}, params)
  end

  @spec changeset(t, map) :: changeset
  def changeset(%__MODULE__{} = struct, %{} = params) do
    struct
    |> cast(params, [:name, :system_id])
    |> validate_required([:name, :system_id])
    |> cast_assoc(:filters)
    |> cast_assoc(:rules, required: true)
    |> unique_constraint([:system_id, :name])
  end
end
