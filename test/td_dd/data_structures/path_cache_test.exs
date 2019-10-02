defmodule TdDd.DataStructures.PatchCacheTest do
  use TdDd.DataStructureCase

  alias TdDd.DataStructures.PathCache

  setup_all do
    start_supervised(PathCache)
    :ok
  end

  describe "TdDd.DataStructures.PathCache" do
    test "path/1 returns the path of a data structure version" do
      dsvs = create_hierarchy(["foo", "bar", "baz", "xyzzy"])
      PathCache.refresh()
      paths = Enum.map(dsvs, &PathCache.path(&1.id))
      assert paths == [[], ["foo"], ["foo", "bar"], ["foo", "bar", "baz"]]
    end
  end
end
