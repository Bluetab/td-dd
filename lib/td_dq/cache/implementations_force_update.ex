defmodule TdDq.Cache.ImplementationsForceUpdate do
  @moduledoc """
  Task to force refresh structure cache
  """

  alias TdCache.Redix
  alias TdDq.Cache.ImplementationLoader

  def migrate do
    # Update cache implementations
    # Add descriptions
    if acquire_lock?("TD-4922") || acquire_lock?("TD-5840") do
      ImplementationLoader.refresh(force: true)
    end
  end

  ## Private functions

  defp acquire_lock?(key) do
    Redix.acquire_lock?(key)
  end
end
