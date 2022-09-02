defmodule TdDdWeb.Schema.Types.Custom.Cursor do
  @moduledoc """
  The Cursor scalar type represents an opaque cursor used for pagination.
  """
  use Absinthe.Schema.Notation

  scalar :cursor, name: "Cursor" do
    description("""
    The `Cursor` scalar type represents an opaque cursor used for pagination
    """)

    parse(&decode/1)
    serialize(&encode/1)
  end

  @spec decode(Absinthe.Blueprint.Input.String.t()) :: {:ok, term()} | :error
  @spec decode(Absinthe.Blueprint.Input.Null.t()) :: {:ok, nil}
  def decode(%Absinthe.Blueprint.Input.String{value: data}), do: Base.decode64(data)
  def decode(%Absinthe.Blueprint.Input.Null{}), do: {:ok, nil}
  def decode(_), do: :error

  def encode(nil), do: nil
  def encode(value) when is_binary(value), do: Base.encode64(value)
  def encode(value) when is_integer(value), do: Base.encode64(to_string(value))
end
