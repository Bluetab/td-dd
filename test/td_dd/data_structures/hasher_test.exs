defmodule TdDd.DataStructures.HasherTest do
  use ExUnit.Case, async: true

  alias TdDd.DataStructures.Hasher

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
  end
end
