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
    changeset
    |> Ecto.Changeset.traverse_errors(fn {message, opts} ->
      Enum.reduce(opts, message, fn
        {_key, {_type, details}}, acc when is_list(details) ->
          add_details(acc, details)

        {key, value}, acc ->
          String.replace(acc, "%{#{key}}", inspect(value))
      end)
    end)
    |> Enum.map(fn {key, value} -> %{message: "#{value}", field: key} end)
  end

  defp add_details(message, details) when is_binary(message) and is_list(details) do
    Enum.reduce(details, message, fn
      {:validation, value}, acc ->
        acc <> " - #{value}"

      _other, acc ->
        acc
    end)
  end
end
