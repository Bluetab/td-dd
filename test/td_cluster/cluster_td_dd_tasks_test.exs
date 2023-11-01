defmodule TdCluster.ClusterTdDdTasksTest do
  use ExUnit.Case
  use TdDd.DataCase

  alias TdCluster.Cluster
  alias TdDd.Search

  @moduletag sandbox: :shared

  setup do
    start_supervised!(Search.Tasks)
    :ok
  end

  describe "test Cluster.TdDd.Tasks functions" do
    test "correctly handles task logging lifecycle" do
      index = :fake_index

      {:ok, :ok} = Cluster.TdDd.Tasks.log_start(index)

      assert [
               {_,
                %{
                  index: ^index,
                  status: :started
                }}
             ] =
               Search.Tasks.ets_table()
               |> :ets.tab2list()

      Cluster.TdDd.Tasks.log_start_stream(100_000)

      assert [
               {_,
                %{
                  index: ^index,
                  status: :started_stream,
                  count: 100_000
                }}
             ] =
               Search.Tasks.ets_table()
               |> :ets.tab2list()

      Cluster.TdDd.Tasks.log_progress(1000)

      assert [
               {_,
                %{
                  index: ^index,
                  status: :processing,
                  processed: 1000
                }}
             ] =
               Search.Tasks.ets_table()
               |> :ets.tab2list()

      Cluster.TdDd.Tasks.log_end()

      assert [
               {_,
                %{
                  index: ^index,
                  status: :done
                }}
             ] =
               Search.Tasks.ets_table()
               |> :ets.tab2list()
    end
  end
end
