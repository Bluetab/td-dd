defmodule TdDd.DataStructures.DataStructureQueriesTest do
  use TdDd.DataStructureCase

  import TdDd.TestOperators

  alias TdDd.DataStructures.DataStructureQueries
  alias TdDd.Repo

  describe "DataStructureQueries.data_structures_query/1" do
    test "filters by deleted" do
      %{data_structure_id: id} = insert(:data_structure_version)
      _deleted_version = insert(:data_structure_version, deleted_at: DateTime.utc_now())

      assert [%{id: ^id}] = query_data_structures(deleted: false)
    end

    test "filters by external_id" do
      %{external_id: external_id1} = insert(:data_structure)
      %{external_id: external_id2} = insert(:data_structure)

      assert [%{external_id: ^external_id1}] = query_data_structures(external_id: external_id1)
      assert [_, _] = query_data_structures(external_id: [external_id1, external_id2])
    end

    test "filters by ids" do
      %{id: id1} = insert(:data_structure)
      %{id: id2} = insert(:data_structure)

      assert [%{id: ^id1}] = query_data_structures(ids: [id1])
      assert [_, _] = query_data_structures(ids: [id1, id2])
    end

    test "filters by min_id" do
      _lower_id = insert(:data_structure)
      %{id: id} = insert(:data_structure)

      assert [%{id: ^id}] = query_data_structures(min_id: id)
    end

    test "limits results" do
      for _i <- 1..5, do: insert(:data_structure)

      assert [_, _] = query_data_structures(limit: 2)
    end

    test "orders results" do
      for _i <- 1..5, do: insert(:data_structure)
      insert(:data_structure, id: -123)

      ids = query_data_structures(order_by: "id") |> Enum.map(& &1.id)
      assert ids == Enum.sort(ids)
    end

    test "preloads associations" do
      %{name: type_name} = insert(:data_structure_type)

      %{data_structure: %{system_id: system_id}} =
        insert(:data_structure_version, type: type_name)

      assert [%{system: system, current_version: dsv}] =
               query_data_structures(preload: [:system, current_version: :structure_type])

      assert %{id: ^system_id} = system
      assert %{structure_type: %{name: ^type_name}} = dsv
    end

    test "filters by lineage units" do
      _without_lineage = insert(:data_structure)

      %{structure_id: id} =
        insert(:node, units: [build(:unit)], structure: build(:data_structure))

      assert [%{id: ^id}] = query_data_structures(lineage: true)
    end

    test "filters by updated_at" do
      _updated_before = insert(:data_structure)
      %{updated_at: updated_at} = insert(:data_structure)

      assert [%{updated_at: ^updated_at}] = query_data_structures(since: updated_at)
    end
  end

  test "grant DataStructureVersion children" do
    [
      %{id: dsv_a_id} = dsv_a,
      %{id: dsv_b_id},
      %{id: dsv_c_id}
    ] =
      ["A", "B", "C"]
      |> create_hierarchy()

    %{data_structure: %{id: dsv_a_ds_id}} = dsv_a

    %{id: grant_id} = grant = insert(:grant, data_structure_id: dsv_a_ds_id)

    assert [
      %{
        dsv_children: dsv_children,
        grant: ^grant
      }
    ] =
    DataStructureQueries.children(%{grant_ids: [grant_id]})
    |> Repo.all()
    assert dsv_children <|> [dsv_a_id, dsv_b_id, dsv_c_id]
  end

  describe "DataStructureQueries.enriched_structure_versions/1" do
    test "compare with path snapshot" do
      dsv_names = ["foo", "bar", "baz", "xyzzy", "spqr"]
      dsvs = create_hierarchy(dsv_names)
      ids = Enum.map(dsvs, & &1.id)

      paths =
        DataStructureQueries.enriched_structure_versions(%{ids: ids})
        |> Repo.all()
        |> Enum.map(fn %{path: path} ->
          Enum.map(path, &Map.take(&1, ["name"]))
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

      ids_0 = Enum.map(dsvs_0, & &1.id)
      ids_1 = Enum.map(dsvs_1, & &1.id)
      ids_2 = Enum.map(dsvs_2, & &1.id)

      ids = ids_0 ++ ids_1 ++ ids_2

      paths =
        DataStructureQueries.enriched_structure_versions(%{ids: ids})
        |> Repo.all()
        |> Enum.map(fn %{path: path} ->
          Enum.map(path, &Map.take(&1, ["name"]))
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

  defp query_data_structures(clauses) do
    clauses
    |> DataStructureQueries.data_structures_query()
    |> Repo.all()
  end
end
