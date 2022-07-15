defmodule TdDd.Utils.ChangesetUtils do
  @moduledoc false

  import Ecto.Changeset

  @doc """
  A helper that transforms changeset errors into a list of messages.

      Example
      Changeset errors sample: [
          description: {"should be at most %{count} character(s)",
          [count: 10, validation: :length, kind: :max, type: :string]}
      ]
      Initial accumulator: "should be at most %{count} character(s)"
      Replaced to: "should be at most 10 character(s)"
  """
  def error_message_list_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Enum.reduce(opts, message, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> Enum.map(fn {key, value} ->
      %{
        message: "#{value}",
        field: key
      }
    end)
  end

  def validate_required_either(changeset, fields) do
    if Enum.any?(fields, &present?(changeset, &1)) do
      changeset
    else
      add_error(changeset, :required_either, "Either one of these fields must be present: #{atom_list_to_string(fields)}")
    end
  end

  def present?(changeset, field) do
    value = get_field(changeset, field)
    value != nil && value != "" && value != %{}
  end

  defp atom_list_to_string(field_list) do
    field_list
    |> Enum.map_join(", ", & &1)
  end

end
