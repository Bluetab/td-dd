defmodule TdDq.Implementations.RawContent do
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
    field(:database, :string)
    field(:source_id, :integer)
    field(:source, :map, virtual: true)
  end

  def changeset(%__MODULE__{} = struct, params) do
    struct
    |> cast(params, [:dataset, :population, :validations, :source_id, :database])
    |> update_change(:dataset, &maybe_decode/1)
    |> update_change(:population, &maybe_decode/1)
    |> update_change(:validations, &maybe_decode/1)
    |> valid_content?([:dataset, :population, :validations])
    |> validate_required([:dataset, :validations, :source_id])
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
      Regex.run(
        ~r/(?i)(\b(DROP|DELETE|DEL|INSERT|UPDATE|CALL|EXEC|EXECUTE|ALTER|CREATE)\b|--)(?=(?:[^"]*"[^"]*")*[^"]*$)(?=(?:[^']*'[^']*')*[^']*$)/,
        text
      )

    result != nil && length(result) > 0
  end

  defp maybe_decode(value) do
    case Base.decode64(value) do
      {:ok, decoded} -> decoded
      :error -> value
    end
  end
end
