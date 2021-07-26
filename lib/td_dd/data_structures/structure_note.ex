defmodule TdDd.DataStructures.StructureNote do
  @moduledoc """
  Ecto schema module for structure note
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias TdDd.DataStructures.DataStructure
  alias TdDd.DataStructures.Validation
  alias TdDd.Utils.CollectionUtils
  alias TdDfLib.Content

  schema "structure_notes" do
    field :df_content, :map

    field :status, Ecto.Enum,
      values: [:draft, :pending_approval, :rejected, :published, :versioned, :deprecated]

    field :version, :integer
    belongs_to(:data_structure, DataStructure)

    timestamps()
  end

  @doc false
  def bulk_update_changeset(%{df_content: current_content} = structure_note, attrs) do
    structure_note
    |> cast(attrs, [:df_content, :status])
    |> update_change(:df_content, &Content.merge(&1, current_content))
    |> validate_content(structure_note, attrs)
    |> validate_required([:df_content, :status])
  end

  @doc false
  def changeset(structure_note, attrs) do
    structure_note
    |> cast(attrs, [:status, :df_content])
    |> validate_required([:status, :df_content])
    # Validation.validator(structure_note))
    |> validate_change(:df_content, Validation.validator(structure_note))
  end

  @doc false
  def create_changeset(structure_note, data_structure, attrs) do
    structure_note
    |> cast(attrs, [:status, :version, :df_content])
    |> put_assoc(:data_structure, data_structure)
    |> validate_required([:status, :version, :df_content, :data_structure])
    |> validate_change(:df_content, Validation.validator(data_structure))
    |> unique_constraint([:data_structure, :version])
  end

  defp validate_content(
         %{valid?: true, changes: %{df_content: df_content}} = changeset,
         structure_note,
         params
       )
       when is_map(df_content) do
    fields =
      params
      |> CollectionUtils.atomize_keys()
      |> Map.get(:df_content, %{})
      |> Map.keys()

    case Validation.validator(structure_note, df_content, fields) do
      {:error, error} ->
        add_error(changeset, :df_content, "invalid_template", reason: error)

      %{valid?: false, errors: [_ | _] = errors} ->
        add_error(changeset, :df_content, "invalid_content", errors)

      _ ->
        changeset
    end
  end

  defp validate_content(changeset, _structure_note, _params), do: changeset
end
