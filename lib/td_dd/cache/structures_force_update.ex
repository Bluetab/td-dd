defmodule TdDd.Cache.StructuresForceUpdate do
  @moduledoc """
  Task to force refresh structure cache
  """

  alias TdCache.Redix
  alias TdDd.Cache.StructureLoader

  def migrate do
    # Update domain_ids
    # Add descriptions
    if acquire_lock?("TdDd.Cache.Migration:TD-3878") ||
         acquire_lock?("TdDd.Cache.Migration:TD-4378") do
      StructureLoader.refresh(force: true)
    end
  end

  ## Private functions

  defp acquire_lock?(key) do
    Redix.command!(["SET", key, node(), "NX"])
  end
end
