defmodule TdDd.Systems.System do
  @moduledoc """
  Ecto schema module for Systems.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias TdDd.Classifiers.Classifier
  alias TdDd.DataStructures.DataStructure
  alias TdDfLib.Validation

  @type t :: %__MODULE__{}
  @typep changeset :: Ecto.Changeset.t()

  schema "systems" do
    field(:external_id, :string)
    field(:name, :string)
    field(:df_content, :map)

    has_many(:data_structures, DataStructure)
    has_many(:classifiers, Classifier)
    timestamps()
  end

  @spec changeset(map) :: changeset
  def changeset(params) do
    changeset(%__MODULE__{}, params)
  end

  @spec changeset(t, map) :: changeset
  def changeset(%__MODULE__{} = system, params) do
    system
    |> cast(params, [:name, :external_id, :df_content])
    |> validate_required([:name, :external_id])
    |> validate_content()
    |> unique_constraint(:external_id)
  end

  defp validate_content(
         %Ecto.Changeset{valid?: true, changes: %{df_content: df_content}} = changeset
       )
       when map_size(df_content) !== 0 do
    validate_change(changeset, :df_content, Validation.validator("System"))
  end

  defp validate_content(changeset), do: changeset
end
