defmodule TdDd.Classifiers.Rule do
  @moduledoc """
  Ecto Schema module for classifier rules.
  """

  use Ecto.Schema

  alias TdDd.Classifiers.Classifier
  alias TdDd.Classifiers.Filter
  alias TdDd.DataStructures.Classification

  import Ecto.Changeset

  @typedoc "A classifier rule"
  @type t :: %__MODULE__{}
  @typep changeset :: Ecto.Changeset.t()

  schema "classifier_rules" do
    field :path, {:array, :string}
    field :priority, :integer, default: 0
    field :values, {:array, :string}
    field :regex, :string
    field :class, :string
    belongs_to :classifier, Classifier
    has_many :classifications, Classification
    timestamps(type: :utc_datetime_usec)
  end

  @spec changeset(map) :: changeset
  def changeset(%{} = params) do
    changeset(%__MODULE__{}, params)
  end

  @spec changeset(t, map) :: changeset
  def changeset(%__MODULE__{} = struct, %{} = params) do
    struct
    |> cast(params, [:class, :classifier_id, :priority, :values, :regex, :path])
    |> validate_required([:class, :path, :priority])
    |> validate_length(:values, min: 1)
    |> validate_length(:path, min: 1)
    |> validate_change(:path, &path_validator/2)
    |> validate_change(:regex, &regex_validator/2)
    |> update_change(:values, &Enum.uniq/1)
    |> foreign_key_constraint(:classifier_id)
    |> check_constraint(:values, name: :values_xor_regex)
  end

  defdelegate path_validator(field, changeset), to: Filter

  defdelegate regex_validator(field, changeset), to: Filter
end
