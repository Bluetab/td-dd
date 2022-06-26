defmodule TdDd.DataStructures.StructureNote do
  @moduledoc """
  Ecto schema module for structure note
  """
  use Ecto.Schema

  import Ecto.Changeset

  alias TdDd.DataStructures.DataStructure
  alias TdDd.DataStructures.StructureNote
  alias TdDd.DataStructures.Validation
  alias TdDd.Utils.CollectionUtils
  alias TdDfLib.Content

  @typedoc "A data structure note"
  @type t :: %__MODULE__{}

  schema "structure_notes" do
    field(:df_content, :map)

    field(:status, Ecto.Enum,
      values: [:draft, :pending_approval, :rejected, :published, :versioned, :deprecated]
    )

    field(:version, :integer)
    field(:resource, :map, virtual: true, default: %{})
    field(:domain_ids, {:array, :integer}, virtual: true, default: [])
    belongs_to(:data_structure, DataStructure)

    timestamps()
  end

  def bulk_update_changeset(%{df_content: old_content} = structure_note, attrs) do
    structure_note
    |> cast(attrs, [:df_content, :status])
    |> update_change(:df_content, &Content.merge(&1, old_content))
    |> maybe_put_identifier(structure_note)
    |> validate_content(structure_note, attrs)
    |> validate_required([:df_content, :status])
  end

  def changeset(%{df_content: _old_content} = structure_note, attrs) do
    structure_note
    |> cast(attrs, [:status, :df_content])
    |> validate_required([:status, :df_content])
    |> maybe_put_identifier(structure_note)
    |> validate_change(:df_content, Validation.validator(structure_note))
  end

  def bulk_create_changeset(
        %{df_content: old_content} = structure_note,
        data_structure,
        attrs
      ) do
    %__MODULE__{}
    |> cast(attrs, [:status, :version, :df_content])
    |> update_change(:df_content, &Content.merge(&1, old_content))
    |> put_assoc(:data_structure, data_structure)
    |> validate_required([:status, :version, :df_content, :data_structure])
    |> maybe_put_identifier(structure_note, data_structure)
    |> validate_change(:df_content, Validation.shallow_validator(data_structure))
    |> validate_content(%{structure_note | data_structure_id: data_structure.id}, attrs)
    |> unique_constraint([:data_structure, :version])
  end

  def create_changeset(
        structure_note,
        %DataStructure{} = data_structure,
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
        validate_change(changeset, :df_content, &TdDfLib.Validation.validate_safe/2)
    end
  end

  defp validate_content(changeset, _structure_note, _params),
    do: validate_change(changeset, :df_content, &TdDfLib.Validation.validate_safe/2)

  defp maybe_put_identifier(
         changeset,
         %StructureNote{
           df_content: old_content,
           data_structure: %DataStructure{
             current_version: %{structure_type: %{template_id: template_id}}
           }
         }
       ) do
    maybe_put_identifier_aux(changeset, old_content, template_id)
  end

  defp maybe_put_identifier(
         changeset,
         %DataStructure{
           current_version: %{
             structure_type: %{
               template_id: template_id
             }
           }
         } = data_structure
       ) do
    case data_structure do
      %DataStructure{
        latest_note: %{df_content: old_content}
      } ->
        maybe_put_identifier_aux(changeset, old_content, template_id)

      %DataStructure{} ->
        maybe_put_identifier_aux(changeset, %{}, template_id)
    end
  end

  defp maybe_put_identifier(changeset, _structure_note_or_data_structure) do
    changeset
  end

  defp maybe_put_identifier(
         changeset,
         %StructureNote{df_content: old_content},
         %DataStructure{current_version: %{structure_type: %{template_id: template_id}}}
       ) do
    maybe_put_identifier_aux(changeset, old_content, template_id)
  end

  defp maybe_put_identifier(changeset, _structure_note, _data_structure) do
    changeset
  end

  defp maybe_put_identifier_aux(
         %{valid?: true, changes: %{df_content: changeset_content}} = changeset,
         old_content,
         template_id
       ) do
    new_content =
      TdDfLib.Format.maybe_put_identifier_by_id(changeset_content, old_content, template_id)

    put_change(changeset, :df_content, new_content)
  end

  defp maybe_put_identifier_aux(changeset, _, _), do: changeset
end
