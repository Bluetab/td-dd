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

  @template_name "System"

  schema "systems" do
    field(:external_id, :string)
    field(:name, :string)
    field(:df_content, :map)

    has_many(:data_structures, DataStructure)
    has_many(:classifiers, Classifier)
    timestamps()
  end

  def _test_get_template_name do
    @template_name
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
    |> maybe_put_identifier(system, @template_name)
    |> validate_content()
    |> unique_constraint(:external_id)
  end

  defp maybe_put_identifier(
         changeset,
         %__MODULE__{df_content: current_content} = _system,
         template_name
       ) do
    maybe_put_identifier_aux(changeset, current_content, template_name)
  end

  defp maybe_put_identifier(
         changeset,
         %__MODULE__{} = _system,
         template_name
       ) do
    maybe_put_identifier_aux(changeset, %{}, template_name)
  end

  defp maybe_put_identifier(changeset, _, _), do: changeset

  defp maybe_put_identifier_aux(
    %{valid?: true, changes: %{df_content: content}} = changeset,
    current_content,
    template_name) do

    TdDfLib.Format.maybe_put_identifier(current_content, content, template_name)
    |> (fn content ->
      put_change(changeset, :df_content, content)
    end).()
  end

  defp maybe_put_identifier_aux(changeset, _, _), do: changeset

  defp validate_content(
         %Ecto.Changeset{valid?: true, changes: %{df_content: df_content}} = changeset
       )
       when map_size(df_content) !== 0 do
    validate_change(changeset, :df_content, Validation.validator(@template_name))
  end

  defp validate_content(changeset), do: changeset
end
