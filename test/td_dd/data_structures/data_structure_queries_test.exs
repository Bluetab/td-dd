defmodule TdDd.DataStructures.DataStructureQueriesTest do
  use TdDd.DataStructureCase

  alias TdDd.DataStructures.DataStructureQueries
  alias TdDd.DataStructures.Hierarchy
  alias TdDd.DataStructures.RelationTypes
  alias TdDd.Repo

  describe "data structure queries" do
    test "calculates has_field_child property" do
      relation_type_id = RelationTypes.default_id!()

      dsv1 = insert(:data_structure_version, name: "dsv1")
      dsv11 = insert(:data_structure_version, name: "dsv11")
      dsv111 = insert(:data_structure_version, name: "dsv111", class: "field")
      dsv12 = insert(:data_structure_version, name: "dsv12")
      dsv121 = insert(:data_structure_version, name: "dsv121", class: "field")

      create_relation(dsv1, dsv11, relation_type_id)
      create_relation(dsv1, dsv12, relation_type_id)
      create_relation(dsv11, dsv111, relation_type_id)
      create_relation(dsv12, dsv121, relation_type_id)

      ids = Enum.map([dsv1, dsv11, dsv111, dsv12, dsv121], &(&1.id))

      assert [
        %{has_field_child: false, name: "dsv1"},
        %{has_field_child: true, name: "dsv11"},
        %{has_field_child: false, name: "dsv111"},
        %{has_field_child: true, name: "dsv12"},
        %{has_field_child: false, name: "dsv121"}
      ] = DataStructureQueries.enriched_structure_versions(%{ids: ids})
      |> Repo.all()
      |> Enum.map(&(Map.take(&1, [:name, :has_field_child])))
    end

    defp create_relation(%{id: parent_id}, %{id: child_id}, relation_type_id) do
      insert(:data_structure_relation,
        parent_id: parent_id,
        child_id: child_id,
        relation_type_id: relation_type_id
      )
    end

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
