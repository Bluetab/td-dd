defmodule TdDdWeb.Schema.Types.Custom.DataURL do
  @moduledoc """
  The DataURL scalar type allows Data URLs to be passed in.
  """
  use Absinthe.Schema.Notation

  scalar :data_url, name: "DataURL" do
    description("""
    The `DataURL` scalar type represents DataURL encoded data.
    """)

    parse(&decode/1)
    serialize(&encode/1)
  end

  @spec decode(Absinthe.Blueprint.Input.String.t()) :: {:ok, term()} | :error
  @spec decode(Absinthe.Blueprint.Input.Null.t()) :: {:ok, nil}
  def decode(%Absinthe.Blueprint.Input.String{value: data}) do
    with ["data", data] <- String.split(data, ":", parts: 2),
         [headers, data] <- String.split(data, ",", parts: 2),
         {["base64"], _} <- media_types(headers) do
      Base.decode64(data)
    else
      _ -> :error
    end
  end

  def decode(%Absinthe.Blueprint.Input.Null{}) do
    {:ok, nil}
  end

  def decode(_) do
    :error
  end

  defp encode(_value), do: :error

  defp media_types(headers) do
    headers
    |> String.split(";")
    |> Enum.split_with(&(&1 == "base64"))
  end
end
