defmodule TdDd.Utils.ChangesetUtils do
  @moduledoc false

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
end
