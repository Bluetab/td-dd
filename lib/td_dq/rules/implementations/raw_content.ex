defmodule TdDq.Rules.Implementations.RawContent do
  @moduledoc """
  Ecto Schema module for "native" rule content.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field(:dataset, :string)
    field(:population, :string)
    field(:validations, :string)
    field(:system, :integer)
    field(:structure_alias, :string)
  end

  def changeset(%__MODULE__{} = struct, params) do
    struct
    |> cast(params, [:dataset, :population, :validations, :system, :structure_alias])
    |> valid_content?([:dataset, :population, :validations])
    |> validate_required([:dataset, :validations])
    |> validate_required_inclusion([:system, :structure_alias])
  end

  def validate_required_inclusion(changeset, fields) do
    if Enum.any?(fields, &present?(changeset, &1)) do
      changeset
    else
      add_error(
        changeset,
        hd(fields),
        "One of these fields must be present: [system, structure_alias]"
      )
    end
  end

  def present?(changeset, field) do
    value = get_field(changeset, field)
    value != nil && value != "" && value != %{}
  end

  defp valid_content?(changeset, fields) do
    Enum.reduce(fields, changeset, fn field, changeset ->
      field_value = get_change(changeset, field)

      case has_invalid_content(field_value) do
        true ->
          add_error(changeset, field, "invalid.#{field}",
            validation: String.to_atom("invalid_content")
          )

        _ ->
          changeset
      end
    end)
  end

  def has_invalid_content(nil) do
    false
  end

  def has_invalid_content(text) do
    result =
      Regex.run(~r/(?i)(\b(DROP|DELETE|INSERT|UPDATE|CALL|EXEC|EXECUTE|ALTER)\b|;|--|#)/, text)

    result != nil && length(result) > 0
  end
end
