defmodule TdDq.Rules.Implementations.Tasks do
  @moduledoc """
  Module providing periodic tasks relating to rule implementations
  """

  alias TdDq.Rules.Implementations

  require Logger

  @doc """
  Deprecate implementations whose structures have been deleted.
  """
  def deprecate_implementations do
    with res <- Implementations.deprecate_implementations(),
         {:ok, %{deprecated: {n, _}}} when n > 0 <- res do
      Logger.info("Deprecated #{n} implementations")
    else
      :ok -> :ok
      {:ok, %{deprecated: {0, _}}} -> :ok
      {:error, op, _, _} -> Logger.warn("Failed to deprecate implementations #{op}")
    end
  end
end
