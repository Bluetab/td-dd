defmodule TdDd.Classifiers.Filter do
  @moduledoc """
  Ecto Schema module for classifier filters.
  """

  use Ecto.Schema

  alias TdDd.Classifiers.Classifier

  import Ecto.Changeset

  @typedoc "A classifier filter"
  @type t :: %__MODULE__{}
  @typep changeset :: Ecto.Changeset.t()

  schema "classifier_filters" do
    field :path, {:array, :string}
    field :values, {:array, :string}
    field :regex, EctoRegex
    belongs_to :classifier, Classifier
    timestamps(type: :utc_datetime_usec)
  end

  @spec changeset(map) :: changeset
  def changeset(%{} = params) do
    changeset(%__MODULE__{}, params)
  end

  @spec changeset(t, map) :: changeset
  def changeset(%__MODULE__{} = struct, %{} = params) do
    struct
    |> cast(params, [:classifier_id, :path, :values, :regex])
    |> validate_required(:path)
    |> validate_length(:values, min: 1)
    |> validate_length(:path, min: 1)
    |> update_change(:values, &Enum.uniq/1)
    |> foreign_key_constraint(:classifier_id)
    |> check_constraint(:values, name: :values_xor_regex)
  end
end
