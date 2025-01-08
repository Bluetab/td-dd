defmodule TdCxWeb.ErrorHelpers do
  @moduledoc """
  Conveniences for translating and building error messages.
  """

  def translate_error({msg, opts}) do
    Enum.reduce(opts, msg, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", fn _ -> to_string(value) end)
    end)
  end
end
