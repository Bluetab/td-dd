defmodule TdDd.DataStructures.HistoryManager do
  @moduledoc """
  Provides functionality for purging logically deleted data structure versions
  and metadata versions.
  """

  alias Ecto.Multi
  alias TdDd.DataStructures.DataStructureVersion
  alias TdDd.DataStructures.StructureMetadata
  alias TdDd.Repo

  import Ecto.Query

  require Logger

  def purge_history do
    :td_dd
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(:history_depth_days)
    |> purge_history()
  end

  def purge_history(nil), do: :ok

  def purge_history(days) when is_integer(days) and days > 0 do
    [q1, q2] =
      Enum.map([DataStructureVersion, StructureMetadata], fn q ->
        where(q, [d], d.deleted_at <= datetime_add(^DateTime.utc_now(), -(^days), "day"))
      end)

    Multi.new()
    |> Multi.delete_all(:data_structure_versions, q1)
    |> Multi.delete_all(:structure_metadata, q2)
    |> Repo.transaction()
    |> log_result()
  end

  defp log_result({:ok, %{data_structure_versions: {0, _}, structure_metadata: {0, _}}} = res) do
    res
  end

  defp log_result({:ok, %{data_structure_versions: {c1, _}, structure_metadata: {c2, _}}} = res) do
    Logger.info("Purged #{c1} structure versions, #{c2} metadata versions")
    res
  end
end
