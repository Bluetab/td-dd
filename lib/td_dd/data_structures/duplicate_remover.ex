defmodule TdDd.DataStructures.DuplicateRemover do
  @moduledoc """
  A Task to remove duplicate data structure versions, which have the same data_structure_id and version
  as another data structure version. Data structure versions which have parent/child or field relations
  will not be deleted. After duplicates are deleted, their corresponding data structures are reindexed
  in the search engine.

  TODO: In Truedat 3.2, a constraint should be applied to the data_structure_version table (via an Ecto 
  migration) to prevent duplicate data_structure_id/version.
  """
  use Task

  import Ecto.Query, warn: false

  alias Ecto.Adapters.SQL
  alias TdDd.DataStructures.DataStructure
  alias TdDd.DataStructures.DataStructureVersion
  alias TdDd.Repo
  alias TdDd.Search.IndexWorker

  require Logger

  def start_link(arg) do
    Task.start_link(__MODULE__, :run, [arg])
  end

  def run(_options), do: :ok

  def run(_options) do
    query = """
    select duplicate.id from data_structure_versions duplicate \
    join data_structure_versions original on original.data_structure_id = duplicate.data_structure_id and original.version = duplicate.version and original.id != duplicate.id \
    and duplicate.id not in (select child_id from data_structure_relations) \
    and duplicate.id not in (select parent_id from data_structure_relations) \
    and duplicate.id not in (select data_structure_version_id from versions_fields)\
    """

    ids = Repo |> SQL.query!(query) |> Map.get(:rows) |> Enum.flat_map(& &1)

    # credo:disable-for-lines:2 Credo.Check.Refactor.PipeChainStart
    from(v in DataStructureVersion, where: v.id in ^ids, select: v.data_structure_id)
    |> Repo.delete_all()
    |> post_process()
  end

  defp post_process({0, _}) do
    Logger.info("No duplicate data structure versions to delete")
  end

  defp post_process({count, data_structure_ids}) do
    Logger.info("Deleted #{count} duplicate data structure versions")

    # credo:disable-for-lines:2 Credo.Check.Refactor.PipeChainStart
    from(ds in DataStructure, where: ds.id in ^data_structure_ids)
    |> Repo.all()
    |> IndexWorker.reindex()
  end
end
