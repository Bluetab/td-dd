defmodule TdDd.Cache.UpdateDomainIds do
  @moduledoc """
  Task to force refresh structure cache to include domain id.
  """

  alias TdCache.Redix
  alias TdDd.Cache.StructureLoader

  def migrate do
    if acquire_lock?("TdDd.Cache.Migration:TD-3878") do
      StructureLoader.refresh(force: true)
    end
  end

  ## Private functions

  defp acquire_lock?(key) do
    Redix.command!(["SET", key, node(), "NX"])
  end
end
