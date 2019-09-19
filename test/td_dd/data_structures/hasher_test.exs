defmodule TdDd.DataStructures.HasherTest do
  use TdDd.DataStructureCase

  alias TdDd.DataStructures.DataStructureVersion
  alias TdDd.DataStructures.Hasher
  alias TdDd.Repo

  describe "TdDd.DataStructures.Hasher" do
    test "hash/1 calculates the hash of a map" do
      map1 = %{foo: "foo", bar: "bar", metadata: %{"foo" => "bar"}}
      map2 = %{foo: "bar", bar: "foo", metadata: %{"bar" => "foo"}}

      [hash1, hash2] = [map1, map2] |> Enum.map(&Hasher.hash(&1, Map.keys(&1)))

      assert hash1 != hash2
    end

    test "hash/1 calculates the hash of a list ignoring the order" do
      list =
        ["foo", "bar", "baz", "xyzzy"]
        |> Enum.map(&Hasher.hash/1)

      assert Hasher.hash(list) == Hasher.hash(Enum.reverse(list))
    end

    test "hash/1 calculates the hash of a string" do
      assert "foo bar baz xyzzy" |> Hasher.hash() |> byte_size == 32
    end

    test "run/1 calculates the hashes of a data structure and it's ancestors" do
      dsvs = create_hierarchy(["foo", "bar", "baz"])

      assert {:ok, hash: 3, lhash: 3, ghash: 3} = Hasher.run()

      hashes =
        dsvs
        |> Enum.map(&Repo.get(DataStructureVersion, &1.id))
        |> Enum.map(&Map.take(&1, [:hash, :lhash, :ghash]))
        |> Enum.flat_map(&Map.values(&1))

      assert Enum.count(hashes, &is_nil/1) == 0
    end

    test "run/1 with rehash option recalculates the hashes of a data structure and it's ancestors" do
      [foo, bar, baz] = create_hierarchy(["foo", "bar", "baz"])

      assert {:ok, hash: 3, lhash: 3, ghash: 3} = Hasher.run()
      assert {:ok, hash: 1, lhash: 1, ghash: 1} = Hasher.run(rehash: foo)
      assert {:ok, hash: 2, lhash: 2, ghash: 2} = Hasher.run(rehash: bar)
      assert {:ok, hash: 3, lhash: 3, ghash: 3} = Hasher.run(rehash: baz)
    end
  end
end
