defmodule TdDd.DataStructures.DataStructureQueriesTest do
  use TdDd.DataStructureCase

  alias TdDd.DataStructures.DataStructureQueries
  alias TdDd.DataStructures.Hierarchy
  alias TdDd.Repo

  describe "data structure queries" do
    test "compare with path snapshot" do
      dsv_names = ["foo", "bar", "baz", "xyzzy", "spqr"]
      dsvs = create_hierarchy(dsv_names)

      ids =
        dsvs
        |> Enum.map(fn dsv -> Map.get(dsv, :id) end)

      Hierarchy.update_hierarchy(ids)

      paths =
        DataStructureQueries.enriched_structure_versions(%{ids: ids})
        |> Repo.all()
        |> Enum.map(fn p ->
          Map.get(p, :path)
          |> Enum.map(fn pk ->
            Map.take(pk, ["name"])
          end)
        end)

      assert paths == snapshot(dsv_names)
    end

    test "compare different hierarchies with path snapshot" do
      dsv_names_0 = ["foo", "bar"]
      dsv_names_1 = ["baz", "xyzzy", "spqr"]
      dsv_names_2 = ["dksl"]
      dsv_names = [dsv_names_0, dsv_names_1, dsv_names_2]
      dsvs_0 = create_hierarchy(dsv_names_0)
      dsvs_1 = create_hierarchy(dsv_names_1)
      dsvs_2 = create_hierarchy(dsv_names_2)

      ids_0 = dsvs_0 |> Enum.map(fn dsv -> Map.get(dsv, :id) end)
      ids_1 = dsvs_1 |> Enum.map(fn dsv -> Map.get(dsv, :id) end)
      ids_2 = dsvs_2 |> Enum.map(fn dsv -> Map.get(dsv, :id) end)

      ids = ids_0 ++ ids_1 ++ ids_2

      Hierarchy.update_hierarchy(ids)

      paths =
        DataStructureQueries.enriched_structure_versions(%{ids: ids})
        |> Repo.all()
        |> Enum.map(fn p ->
          Map.get(p, :path)
          |> Enum.map(fn pk ->
            Map.take(pk, ["name"])
          end)
        end)

      assert paths == snapshot(dsv_names)
    end
  end

  defp snapshot([["foo", "bar"], ["baz", "xyzzy", "spqr"], ["dksl"]]) do
    [
      [],
      [%{"name" => "foo"}],
      [],
      [%{"name" => "baz"}],
      [%{"name" => "baz"}, %{"name" => "xyzzy"}],
      []
    ]
  end

  defp snapshot(["foo", "bar", "baz", "xyzzy", "spqr"]) do
    [
      [],
      [%{"name" => "foo"}],
      [
        %{"name" => "foo"},
        %{"name" => "bar"}
      ],
      [
        %{"name" => "foo"},
        %{"name" => "bar"},
        %{"name" => "baz"}
      ],
      [
        %{"name" => "foo"},
        %{"name" => "bar"},
        %{"name" => "baz"},
        %{"name" => "xyzzy"}
      ]
    ]
  end
end
