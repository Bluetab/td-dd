defmodule TdDd.Search.StoreTest do
  use TdDd.DataCase

  import ExUnit.CaptureLog

  alias TdDd.DataStructures.DataStructureVersion
  alias TdDd.Search.Store
  alias TdDd.Search.StructureEnricher

  describe "Store.stream/1" do
    setup do
      Application.put_env(Store, :chunk_size, 10)
      start_supervised!(StructureEnricher)
      :ok
    end

    @tag sandbox: :shared
    test "streams enriched chunked data structure versions" do
      Enum.each(1..11, fn _ -> insert(:data_structure_version) end)

      assert Store.transaction(fn ->
               DataStructureVersion
               |> Store.stream()
               |> Enum.count()
             end) == 11

      assert StructureEnricher.count() == 11
    end
  end

  describe "Store.vacuum/0" do
    test "returns :ok and logs messages" do
      assert capture_log(fn ->
               assert :ok = Store.vacuum()
             end) =~ "VACUUM cannot run inside a transaction block"
    end
  end
end
