defmodule TdDd.DataStructures.DataStructureQueriesTest do
  use TdDd.DataStructureCase

  import TdDd.TestOperators

  alias TdCluster.TestHelpers.TdAiMock.Indices
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

    test "filters by domain_ids" do
      %{domain_ids: domain_ids1} = insert(:data_structure, domain_ids: [1])
      %{domain_ids: domain_ids2} = insert(:data_structure, domain_ids: [2])

      assert [%{domain_ids: ^domain_ids1}] = query_data_structures(domain_ids: domain_ids1)
      assert [_, _] = query_data_structures(domain_ids: [domain_ids1, domain_ids2])
    end

    test "filters by systems" do
      %{system_id: system_id1} = insert(:data_structure)
      %{system_id: system_id2} = insert(:data_structure)

      assert [%{system_id: ^system_id1}] = query_data_structures(system_ids: [system_id1])
      assert [_, _] = query_data_structures(system_ids: [system_id1, system_id2])
    end

    test "filters by has_note" do
      %{id: ds_id1} = insert(:data_structure)

      %{id: ds_id2} = ds = insert(:data_structure)
      insert(:structure_note, data_structure: ds, version: 0, status: :published)
      insert(:structure_note, data_structure: ds, version: 1, status: :draft)

      assert [%{id: ^ds_id1}] = query_data_structures(has_note: false)

      assert [%{id: ^ds_id2}] = query_data_structures(has_note: true)

      assert [%{id: ^ds_id1}, %{id: ^ds_id2}] = query_data_structures([])
    end

    test "filters by has_note with statuses" do
      %{id: ds_draft} = ds = insert(:data_structure)
      insert(:structure_note, data_structure: ds, version: 0, status: :published)
      insert(:structure_note, data_structure: ds, version: 1, status: :draft)

      %{data_structure_id: ds_published} = insert(:structure_note, status: :published)

      %{id: ds_pending} = ds = insert(:data_structure)
      insert(:structure_note, data_structure: ds, version: 0, status: :published)
      insert(:structure_note, data_structure: ds, version: 1, status: :pending_approval)

      assert [%{id: ^ds_draft}] = query_data_structures(note_statuses: [:draft])

      assert [%{id: ^ds_draft}, %{id: ^ds_published}] =
               query_data_structures(note_statuses: [:draft, :published])

      assert [%{id: ^ds_pending}] = query_data_structures(note_statuses: [:pending_approval])
    end

    test "filters by data_structure_types" do
      insert(:data_structure_version)

      %{name: ds_type_name} = insert(:data_structure_type, name: "foo")

      %{data_structure_id: ds_id_1} = insert(:data_structure_version, type: ds_type_name)

      %{data_structure_id: ds_id_2} = insert(:data_structure_version, type: ds_type_name)

      query_list =
        [data_structure_types: [ds_type_name]]
        |> query_data_structures()
        |> Enum.map(fn %{id: id} -> %{id: id} end)

      assert [%{id: ds_id_1}, %{id: ds_id_2}] ||| query_list
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

    test "return all results with limits = 0" do
      for _i <- 1..5, do: insert(:data_structure)

      assert length(query_data_structures(limit: 0)) == 5
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

    assert dsv_children ||| [dsv_a_id, dsv_b_id, dsv_c_id]
  end

  test "DataStructureVersion children by data_structure_ids" do
    [
      %{id: dsv_a_id} = dsv_a,
      %{id: dsv_b_id},
      %{id: dsv_c_id}
    ] =
      ["A", "B", "C"]
      |> create_hierarchy()

    %{data_structure: %{id: dsv_a_ds_id}} = dsv_a

    [child] =
      %{data_structure_ids: [dsv_a_ds_id]}
      |> DataStructureQueries.children()
      |> Repo.all()

    assert child.ancestor_ds_id == dsv_a_ds_id
    assert child.dsv_children ||| [dsv_a_id, dsv_b_id, dsv_c_id]
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

  describe "DataStructureQueries.data_structure_versions_with_embeddings/1" do
    test "fetch data structure versions with embeddings" do
      Indices.list_indices(
        &Mox.expect/4,
        [enabled: true],
        {:ok, [%{collection_name: "default"}, %{collection_name: "other"}]}
      )

      embedding = insert(:record_embedding)

      other_embedding =
        insert(:record_embedding,
          data_structure_version: embedding.data_structure_version,
          collection: "other"
        )

      second_embedding = insert(:record_embedding)

      deleted_embedding =
        insert(:record_embedding,
          data_structure_version: build(:data_structure_version, deleted_at: DateTime.utc_now())
        )

      version_without_embedding = insert(:data_structure_version)

      data_structure_ids = [
        embedding.data_structure_version.data_structure_id,
        second_embedding.data_structure_version.data_structure_id,
        deleted_embedding.data_structure_version.data_structure_id,
        version_without_embedding.data_structure_id
      ]

      {:ok, versions} =
        Repo.transaction(fn ->
          data_structure_ids
          |> DataStructureQueries.data_structure_versions_with_embeddings()
          |> Enum.to_list()
        end)

      assert Enum.count(versions) == 2

      assert version = Enum.find(versions, &(&1.id == embedding.data_structure_version.id))

      for embedding <- [embedding, other_embedding] do
        assert result = Enum.find(version.record_embeddings, &(&1.id == embedding.id))
        assert result.dims == embedding.dims
        assert result.embedding == embedding.embedding
        assert result.collection == embedding.collection
      end

      assert version = Enum.find(versions, &(&1.id == second_embedding.data_structure_version.id))
      assert [result] = version.record_embeddings
      assert result.dims == second_embedding.dims
      assert result.embedding == second_embedding.embedding
      assert result.collection == second_embedding.collection
    end
  end

  describe "DataStructureQueries.data_structures_with_outdated_embeddings/1" do
    test "returns data structure ids with stale record embeddings" do
      dsv_without_embedding = insert(:data_structure_version)
      deleted_dsv = insert(:data_structure_version, deleted_at: DateTime.utc_now())
      insert(:record_embedding, data_structure_version: deleted_dsv, collection: "default")
      insert(:record_embedding, data_structure_version: deleted_dsv, collection: "other")
      %{data_structure_version: updated_dsv} = insert(:record_embedding, collection: "default")
      insert(:record_embedding, collection: "other", data_structure_version: updated_dsv)

      %{data_structure_version: outdated_dsv} =
        insert(:record_embedding,
          updated_at: DateTime.add(DateTime.utc_now(), -1, :day),
          collection: "default"
        )

      insert(:record_embedding,
        updated_at: DateTime.add(DateTime.utc_now(), -1, :day),
        collection: "other",
        data_structure_version: outdated_dsv
      )

      data_structure_ids =
        ["default", "other"]
        |> DataStructureQueries.data_structures_with_outdated_embeddings()
        |> Repo.all()

      assert MapSet.equal?(
               MapSet.new(data_structure_ids),
               MapSet.new([
                 outdated_dsv.data_structure_id,
                 dsv_without_embedding.data_structure_id
               ])
             )

      # we add a new embedding missing one of the collections
      %{data_structure_version: missing_other} = insert(:record_embedding)

      data_structure_ids =
        ["default", "other"]
        |> DataStructureQueries.data_structures_with_outdated_embeddings()
        |> Repo.all()

      assert MapSet.equal?(
               MapSet.new(data_structure_ids),
               MapSet.new([
                 outdated_dsv.data_structure_id,
                 dsv_without_embedding.data_structure_id,
                 missing_other.data_structure_id
               ])
             )

      data_structure_ids =
        ["default", "other"]
        |> DataStructureQueries.data_structures_with_outdated_embeddings(limit: 1)
        |> Repo.all()

      assert Enum.count(data_structure_ids) == 1
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
