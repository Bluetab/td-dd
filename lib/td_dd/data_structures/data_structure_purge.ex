defmodule TdDd.DataStructures.DataStructurePurge do
  @moduledoc """
  Provides functionality for purge logically deleted structures
  """
  alias TdDd.DataStructures
  alias TdDd.Search.IndexWorker

  require Logger

  def purge_structure_versions do
    config = Application.get_env(:td_dd, __MODULE__)
    purge_structure_versions(config[:period_of_time])
  end

  def purge_structure_versions(nil), do: {:ok, 0}

  def purge_structure_versions(period_time) when is_integer(period_time) do
    period_time
    |> DataStructures.purge_data_structure_versions()
    |> case do
      {0, _} ->
        {:ok, 0}

      {count, data_structure_ids} ->
        IndexWorker.delete(data_structure_ids)
        Logger.info("Purged #{count} Structure versions")
        {:ok, count}

      _ ->
        {:ok, 0}
    end
  end

  def purge_structure_versions(_), do: {:ok, 0}
end
