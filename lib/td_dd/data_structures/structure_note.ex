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
    field(:df_content, :map)

    field(:status, Ecto.Enum,
      values: [:draft, :pending_approval, :rejected, :published, :versioned, :deprecated]
    )

    field(:version, :integer)
    field(:resource, :map, virtual: true, deafult: %{})
    field(:domain_ids, {:array, :integer}, virtual: true, default: [])
    belongs_to(:data_structure, DataStructure)

    timestamps()
  end

  def bulk_update_changeset(%{df_content: current_content} = structure_note, attrs) do
    structure_note
    |> cast(attrs, [:df_content, :status])
    |> update_change(:df_content, &Content.merge(&1, current_content))
    |> maybe_put_identifier(current_content, attrs)
    |> validate_content(structure_note, attrs)
    |> validate_required([:df_content, :status])
  end

  def changeset(%{df_content: current_content} = structure_note, attrs) do
    structure_note
    |> cast(attrs, [:status, :df_content])
    |> validate_required([:status, :df_content])
    |> maybe_put_identifier(current_content, attrs)
    |> validate_change(:df_content, Validation.validator(structure_note))
  end

  def bulk_create_changeset(
        %{df_content: current_content},
        data_structure,
        attrs
      ) do
    %__MODULE__{}
    |> cast(attrs, [:status, :version, :df_content])
    |> update_change(:df_content, &Content.merge(&1, current_content))
    |> put_assoc(:data_structure, data_structure)
    |> validate_required([:status, :version, :df_content, :data_structure])
    |> maybe_put_identifier(data_structure)
    |> validate_change(:df_content, Validation.shallow_validator(data_structure))
    |> unique_constraint([:data_structure, :version])
  end

  def create_changeset(
        %{df_content: _current_content} = structure_note,
        data_structure,
        attrs
      ) do
    structure_note
    |> cast(attrs, [:status, :version, :df_content])
    |> put_assoc(:data_structure, data_structure)
    |> validate_required([:status, :version, :df_content, :data_structure])
    |> maybe_put_identifier(data_structure)
    |> validate_change(:df_content, Validation.validator(data_structure))
    |> unique_constraint([:data_structure, :version])
  end

  defp validate_content(
         %{valid?: true, changes: %{df_content: df_content}} = changeset,
         data_structure_or_note,
         params
       )
       when is_map(df_content) do
    fields =
      params
      |> CollectionUtils.atomize_keys()
      |> Map.get(:df_content, %{})
      |> Map.keys()

    case Validation.validator(data_structure_or_note, df_content, fields) do
      {:error, error} ->
        add_error(changeset, :df_content, "invalid_template", reason: error)

      %{valid?: false, errors: [_ | _] = errors} ->
        add_error(changeset, :df_content, "invalid_content", errors)

      _ ->
        changeset
    end
  end

  defp validate_content(changeset, _structure_note, _params), do: changeset

  defp maybe_put_identifier(changeset, current_content, %{"type" => template_name}) do
    maybe_put_identifier_aux(changeset, current_content, template_name)
  end

  defp maybe_put_identifier(changeset, _current_content, _attrs), do: changeset

  defp maybe_put_identifier(
         changeset,
         %DataStructure{current_version: %{structure_type: %{template_id: template_id}}}
       ) do
    maybe_put_identifier_aux(changeset, %{}, template_id)
  end

  defp maybe_put_identifier(changeset, _), do: changeset

  defp maybe_put_identifier_aux(
         %{valid?: true, changes: %{df_content: df_content}} = changeset,
         current_content,
         template_id
       ) do
    TdDfLib.Format.maybe_put_identifier_by_id(current_content, df_content, template_id)
    |> (fn content ->
          put_change(changeset, :df_content, content)
        end).()
  end

  defp maybe_put_identifier_aux(changeset, _, _), do: changeset
end
