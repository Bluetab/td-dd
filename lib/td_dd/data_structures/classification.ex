defmodule TdDd.DataStructures.Classification do
  @moduledoc """
  Ecto Schema module for data structure classifications.
  """

  use Ecto.Schema

  alias TdDd.Classifiers.Classifier
  alias TdDd.Classifiers.Rule
  alias TdDd.DataStructures.DataStructureVersion

  @typedoc "A data structure classification"
  @type t :: %__MODULE__{}

  schema "structure_classifications" do
    field :class, :string
    field :name, :string
    belongs_to :data_structure_version, DataStructureVersion
    belongs_to :classifier, Classifier
    belongs_to :rule, Rule
    timestamps(type: :utc_datetime_usec)
  end
end
