defmodule EctoRegex do
  @moduledoc """
  Custom Ecto Type for regular expressions.
  """

  use Ecto.Type

  @spec type :: :string
  def type, do: :string

  @spec cast(any) :: :error | {:ok, Regex.t()}
  def cast(value) when is_binary(value) do
    case Regex.compile(value) do
      {:ok, regex} -> {:ok, regex}
      _ -> :error
    end
  end

  def cast(%Regex{} = regex), do: {:ok, regex}
  def cast(_), do: :error

  @spec load(binary) :: :error | {:ok, Regex.t()}
  def load(data) when is_binary(data), do: cast(data)

  @spec dump(any) :: :error | {:ok, binary()}
  def dump(%Regex{source: source}), do: {:ok, source}
  def dump(_), do: :error
end
