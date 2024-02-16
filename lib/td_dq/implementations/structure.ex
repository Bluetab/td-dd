defmodule TdDq.Implementations.Structure do
  @moduledoc """
  Ecto Schema module for DataStructure references in rule implementations
  """

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field(:id, :integer)
    field(:name, :string)
    field(:parent_index, :integer)
    field(:type, :string)
  end

  def changeset(%{} = params) do
    changeset(%__MODULE__{}, params)
  end

  def changeset(%__MODULE__{} = struct, %{} = params) do
    type = Map.get(params, :type, Map.get(params, "type"))

    struct
    |> cast(params, [:id, :name, :parent_index])
    |> validate_required_by_type(type, params)
  end

  defp validate_required_by_type(struct, "reference_dataset_field", params) do
    struct
    |> cast(params, [:type])
    |> validate_required([:name, :parent_index])
  end

  defp validate_required_by_type(struct, "reference_dataset", params) do
    struct
    |> cast(params, [:type])
    |> validate_required(:id)
  end

  defp validate_required_by_type(struct, _, _) do
    validate_required(struct, [:id])
  end
end
