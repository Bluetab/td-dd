defmodule TdDdWeb.Resolvers.Templates do
  @moduledoc """
  Absinthe resolvers for templates
  """

  def updated_at(%{updated_at: value}, _args, _resolution) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _} -> {:ok, datetime}
      {:error, error} -> {:error, error}
    end
  end
end
