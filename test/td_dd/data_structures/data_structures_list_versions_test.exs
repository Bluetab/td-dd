defmodule TdDd.DataStructuresTestListVersions do
  use TdDd.DataStructureCase

  alias TdDd.DataStructures
  alias TdDd.DataStructures.RelationTypes

  describe "list_data_structure_versions" do
    test "data structure updated_at < since clause" do
      day1 = ~U[2020-01-01 00:00:00Z]
      day2 = ~U[2020-01-02 00:00:00Z]
      day3 = ~U[2020-01-03 00:00:00Z]
      day4 = ~U[2020-01-04 00:00:00Z]
      day5 = ~U[2020-01-05 00:00:00Z]

      # Non updated data structure (inserted_at equals updated_at)
      ds = insert(:data_structure, inserted_at: day1, updated_at: day1)

      _dsv1 =
        insert(:data_structure_version,
          data_structure_id: ds.id,
          version: 0,
          inserted_at: day2,
          updated_at: day2
        )

      _dsv2 =
        insert(:data_structure_version,
          data_structure_id: ds.id,
          version: 1,
          inserted_at: day3,
          updated_at: day3
        )

      dsv3 =
        insert(:data_structure_version,
          data_structure_id: ds.id,
          version: 2,
          inserted_at: day4,
          updated_at: day4
        )

      dsv4 =
        insert(:data_structure_version,
          data_structure_id: ds.id,
          version: 3,
          inserted_at: day1,
          updated_at: day1,
          deleted_at: day5
        )

      assert [^dsv3, ^dsv4] =
               DataStructures.list_data_structure_versions(%{since: day4, order_by: "id"})
    end

    test "data structure updated_at >= since clause" do
      day1 = ~U[2020-01-01 00:00:00Z]
      day2 = ~U[2020-01-02 00:00:00Z]
      day3 = ~U[2020-01-03 00:00:00Z]
      day4 = ~U[2020-01-04 00:00:00Z]
      day5 = ~U[2020-01-05 00:00:00Z]

      # Updated data structure (updated_at greater than inserted_at)
      ds = insert(:data_structure, inserted_at: day1, updated_at: day4)

      dsv1 =
        insert(:data_structure_version,
          data_structure_id: ds.id,
          version: 0,
          inserted_at: day2,
          updated_at: day2
        )

      dsv2 =
        insert(:data_structure_version,
          data_structure_id: ds.id,
          version: 1,
          inserted_at: day3,
          updated_at: day3
        )

      dsv3 =
        insert(:data_structure_version,
          data_structure_id: ds.id,
          version: 2,
          inserted_at: day4,
          updated_at: day4
        )

      dsv4 =
        insert(:data_structure_version,
          data_structure_id: ds.id,
          version: 3,
          inserted_at: day1,
          updated_at: day1,
          deleted_at: day5
        )

      assert [^dsv1, ^dsv2, ^dsv3, ^dsv4] =
               DataStructures.list_data_structure_versions(%{since: day4, order_by: "id"})
    end

    test "since filter works with other filters" do
      dsv1_day = ~U[2019-04-16 00:00:00Z]
      dsv1_ds_day = ~U[2023-05-22 00:00:00Z]
      dsv2_day = ~U[2019-06-17 00:00:00Z]
      dsv2_deleted_day = ~U[2023-04-28 00:00:00Z]
      dsv2_ds_day = ~U[2022-10-25 00:00:00Z]
      since = ~U[2022-11-22 00:00:00Z]

      ds1 = insert(:data_structure, inserted_at: dsv1_ds_day, updated_at: dsv1_ds_day)
      ds2 = insert(:data_structure, inserted_at: dsv2_ds_day, updated_at: dsv2_ds_day)

      dsv1 =
        insert(:data_structure_version,
          data_structure_id: ds1.id,
          version: 0,
          inserted_at: dsv1_day,
          updated_at: dsv1_day
        )

      dsv2 =
        insert(:data_structure_version,
          data_structure_id: ds2.id,
          version: 0,
          inserted_at: dsv2_day,
          updated_at: dsv2_day,
          deleted_at: dsv2_deleted_day
        )

      assert [^dsv2] =
               DataStructures.list_data_structure_versions(%{
                 since: since,
                 min_id: dsv1.id + 1,
                 limit: 3,
                 order_by: "id"
               })
    end

    defp create_testeable_dsv(
           version_updated_date,
           deleted_version,
           structure_updated_date
         ) do
      %{id: ds_id} =
        insert(:data_structure,
          inserted_at: structure_updated_date,
          updated_at: structure_updated_date
        )

      %{id: dsv_id} =
        insert(:data_structure_version,
          data_structure_id: ds_id,
          version: 1,
          inserted_at: version_updated_date,
          updated_at: version_updated_date,
          deleted_at: deleted_version
        )

      dsv_id
    end

    test "complete dates" do
      previous_date = ~U[2019-04-16 00:00:00Z]
      next_date = ~U[2023-05-22 00:00:00Z]
      since_dates = [~U[2019-04-14 00:00:00Z], ~U[2023-05-19 00:00:00Z], ~U[2023-05-26 00:00:00Z]]

      dsv_ids = [
        dsv_id_1_1 = create_testeable_dsv(previous_date, previous_date, previous_date),
        dsv_id_1_2 = create_testeable_dsv(previous_date, previous_date, previous_date),
        create_testeable_dsv(previous_date, previous_date, next_date),
        create_testeable_dsv(previous_date, previous_date, next_date),
        create_testeable_dsv(previous_date, next_date, previous_date),
        create_testeable_dsv(previous_date, next_date, previous_date),
        create_testeable_dsv(previous_date, next_date, next_date),
        create_testeable_dsv(previous_date, next_date, next_date),
        dsv_id_5_1 = create_testeable_dsv(previous_date, nil, previous_date),
        dsv_id_5_2 = create_testeable_dsv(previous_date, nil, previous_date),
        create_testeable_dsv(previous_date, nil, next_date),
        create_testeable_dsv(previous_date, nil, next_date),
        create_testeable_dsv(next_date, previous_date, previous_date),
        create_testeable_dsv(next_date, previous_date, previous_date),
        create_testeable_dsv(next_date, previous_date, next_date),
        create_testeable_dsv(next_date, previous_date, next_date),
        create_testeable_dsv(next_date, next_date, previous_date),
        create_testeable_dsv(next_date, next_date, previous_date),
        create_testeable_dsv(next_date, next_date, next_date),
        create_testeable_dsv(next_date, next_date, next_date),
        create_testeable_dsv(next_date, nil, previous_date),
        create_testeable_dsv(next_date, nil, previous_date),
        create_testeable_dsv(next_date, nil, next_date),
        create_testeable_dsv(next_date, nil, next_date)
      ]

      [dsv_ids_previous, dsv_ids_intermediate, dsv_ids_forward] =
        Enum.map(since_dates, fn since ->
          DataStructures.list_data_structure_versions(%{
            since: since,
            order_by: "id"
          })
          |> Enum.map(& &1.id)
        end)

      assert dsv_ids == dsv_ids_previous
      assert dsv_ids -- [dsv_id_1_1, dsv_id_1_2, dsv_id_5_1, dsv_id_5_2] == dsv_ids_intermediate
      assert [] = dsv_ids_forward

      odd_ids =
        [^dsv_id_1_1 | [_ | [_ | [_ | [^dsv_id_5_1 | _]]]]] = dsv_ids |> Enum.take_every(2)

      [paginated_previous_ids, paginated_intermediate_ids, paginated_forward_ids] =
        Enum.map(since_dates, fn since ->
          Enum.map(odd_ids, fn id ->
            DataStructures.list_data_structure_versions(%{
              since: since,
              order_by: "id",
              min_id: id
            })
            |> Enum.map(& &1.id)
          end)
        end)
        |> Enum.map(&Enum.zip(odd_ids, &1))

      for {odd_id, paginated_previous_ids_per_odd_id} <- paginated_previous_ids do
        assert Enum.filter(dsv_ids_previous, &(&1 >= odd_id)) ==
                 paginated_previous_ids_per_odd_id
      end

      for {odd_id, paginated_intermediate_ids_per_odd_id} <- paginated_intermediate_ids do
        assert Enum.filter(dsv_ids_intermediate, &(&1 >= odd_id)) ==
                 paginated_intermediate_ids_per_odd_id
      end

      for {_odd_id, paginated_forward_ids_per_odd_id} <- paginated_forward_ids do
        assert [] == paginated_forward_ids_per_odd_id
      end
    end
  end

  describe "list_data_structure_metrics" do
    defp link_version_as_child(dsv, opts \\ []) do
      ts = Keyword.get(opts, :updated_at, ~U[2020-01-01 00:00:00Z])

      parent_dsv =
        insert(:data_structure_version,
          data_structure_id: insert(:data_structure, updated_at: ts).id,
          updated_at: ts
        )

      insert(:data_structure_relation,
        parent_id: parent_dsv.id,
        child_id: dsv.id,
        relation_type_id: RelationTypes.default_id!()
      )
    end

    test "returns data structures" do
      %{id: ds1} = insert(:data_structure, last_change_at: ~U[2020-01-01 00:00:00Z])
      %{id: ds2} = insert(:data_structure, last_change_at: ~U[2020-01-02 00:00:00Z])
      %{id: ds3} = insert(:data_structure, last_change_at: ~U[2020-01-03 00:00:00Z])
      %{id: ds4} = insert(:data_structure, last_change_at: ~U[2020-01-04 00:00:00Z])

      insert(:data_structure_version,
        data_structure_id: ds1,
        name: "dsv1",
        deleted_at: ~U[2020-01-02 00:00:00Z]
      )

      insert(:data_structure_version,
        data_structure_id: ds2,
        name: "dsv2",
        deleted_at: ~U[2020-01-03 00:00:00Z]
      )

      insert(:data_structure_version,
        data_structure_id: ds3,
        name: "dsv3",
        deleted_at: ~U[2020-01-04 00:00:00Z]
      )

      insert(:data_structure_version,
        data_structure_id: ds4,
        name: "dsv4",
        deleted_at: nil
      )

      result = DataStructures.list_data_structure_metrics(%{}, 0, 10)

      assert length(result) == 4

      assert Enum.map(result, & &1.id) |> Enum.sort() ==
               [ds1, ds2, ds3, ds4] |> Enum.sort()
    end

    test "ensure all fields are returned" do
      required_fields = [
        :id,
        :parent_id,
        :system_id,
        :class,
        :deleted_at,
        :domain_ids,
        :external_id,
        :inserted_at,
        :updated_at,
        :last_change_at,
        :linked_concepts,
        :metadata,
        :mutable_metadata,
        :name,
        :description,
        :type,
        :field_type,
        :version,
        :source_id,
        :confidential
      ]

      %{id: ds1} = insert(:data_structure, last_change_at: ~U[2020-01-01 00:00:00Z])
      %{id: ds2} = insert(:data_structure, last_change_at: ~U[2020-01-01 00:00:00Z])

      insert(:data_structure_version,
        data_structure_id: ds1,
        name: "dsv1",
        deleted_at: ~U[2020-01-02 00:00:00Z],
        metadata: %{"field_type" => "structure_type"},
        version: 1
      )

      insert(:data_structure_version,
        data_structure_id: ds2,
        name: "dsv1"
      )

      result = DataStructures.list_data_structure_metrics(%{}, 0, 10)

      assert length(result) == 2
      assert Enum.map(result, & &1.id) |> Enum.sort() == [ds1, ds2] |> Enum.sort()

      for item <- result do
        item_keys = item |> Map.keys() |> Enum.sort()

        assert item_keys == Enum.sort(required_fields),
               "expected exactly keys #{inspect(Enum.sort(required_fields))}, got #{inspect(item_keys)}"
      end
    end

    test "sets linked_concepts true for data structures linked to business concepts" do
      %{id: ds_linked} = insert(:data_structure)
      %{id: ds_unlinked} = insert(:data_structure)

      insert(:data_structure_version, data_structure_id: ds_linked, name: "dsv_linked")
      insert(:data_structure_version, data_structure_id: ds_unlinked, name: "dsv_unlinked")

      CacheHelpers.insert_link(ds_linked, "data_structure", "business_concept", nil)

      result = DataStructures.list_data_structure_metrics(%{}, 0, 10)

      linked_row = Enum.find(result, &(&1.id == ds_linked))
      unlinked_row = Enum.find(result, &(&1.id == ds_unlinked))

      assert linked_row.linked_concepts == true
      assert unlinked_row.linked_concepts == false
    end

    test "returns data structures filter by since" do
      since = ~U[2020-01-03 00:00:00Z]

      %{id: ds1} =
        insert(:data_structure,
          last_change_at: ~U[2020-01-01 00:00:00Z],
          updated_at: ~U[2020-01-01 00:00:00Z]
        )

      %{id: ds2} =
        insert(:data_structure,
          last_change_at: ~U[2020-01-02 00:00:00Z],
          updated_at: ~U[2020-01-02 00:00:00Z]
        )

      %{id: ds3} =
        insert(:data_structure,
          last_change_at: ~U[2020-01-03 00:00:00Z],
          updated_at: ~U[2020-01-03 00:00:00Z]
        )

      %{id: ds4} =
        insert(:data_structure,
          last_change_at: ~U[2020-01-04 00:00:00Z],
          updated_at: ~U[2020-01-04 00:00:00Z]
        )

      insert(:data_structure_version,
        data_structure_id: ds1,
        name: "dsv1",
        deleted_at: ~U[2020-01-02 00:00:00Z],
        updated_at: ~U[2020-01-01 00:00:00Z]
      )

      insert(:data_structure_version,
        data_structure_id: ds2,
        name: "dsv2",
        deleted_at: ~U[2020-01-03 00:00:00Z],
        updated_at: ~U[2020-01-02 00:00:00Z]
      )

      dsv3 =
        insert(:data_structure_version,
          data_structure_id: ds3,
          name: "dsv3",
          deleted_at: ~U[2020-01-04 00:00:00Z],
          updated_at: ~U[2020-01-03 00:00:00Z]
        )

      link_version_as_child(dsv3)

      insert(:data_structure_version,
        data_structure_id: ds4,
        name: "dsv4",
        deleted_at: nil,
        updated_at: ~U[2020-01-04 00:00:00Z]
      )

      result = DataStructures.list_data_structure_metrics(%{since: since}, 0, 10)

      assert length(result) == 2

      assert Enum.map(result, & &1.id) |> Enum.sort() ==
               [ds3, ds4] |> Enum.sort()
    end

    test "returns empty list when no structure modifications exist" do
      ds1 =
        insert(:data_structure,
          last_change_at: ~U[2020-01-01 00:00:00Z],
          updated_at: ~U[2020-01-01 00:00:00Z]
        )

      ds2 =
        insert(:data_structure,
          last_change_at: ~U[2020-01-01 00:00:00Z],
          updated_at: ~U[2020-01-01 00:00:00Z]
        )

      insert(:data_structure_version,
        data_structure_id: ds1.id,
        updated_at: ~U[2020-01-01 00:00:00Z]
      )

      insert(:data_structure_version,
        data_structure_id: ds2.id,
        updated_at: ~U[2020-01-01 00:00:00Z]
      )

      result =
        DataStructures.list_data_structure_metrics(%{since: ~U[2020-01-02 00:00:00Z]}, 0, 10)

      assert result == []
    end

    test "respects pagination with page and size" do
      ds1 = insert(:data_structure, last_change_at: ~U[2020-01-01 00:00:00Z])
      ds2 = insert(:data_structure, last_change_at: ~U[2020-01-02 00:00:00Z])
      ds3 = insert(:data_structure, last_change_at: ~U[2020-01-03 00:00:00Z])

      insert(:data_structure_version, data_structure_id: ds1.id)
      insert(:data_structure_version, data_structure_id: ds2.id)
      insert(:data_structure_version, data_structure_id: ds3.id)

      page0 = DataStructures.list_data_structure_metrics(%{}, 0, 2)
      page1 = DataStructures.list_data_structure_metrics(%{}, 1, 2)

      assert length(page0) == 2
      assert length(page1) == 1
      assert [page1_result] = page1
      assert page1_result.id == ds3.id
    end

    test "filters by since clause when latest version deleted_at is after since" do
      since = ~U[2020-01-02 00:00:00Z]

      ds1 =
        insert(:data_structure,
          last_change_at: ~U[2020-01-01 00:00:00Z],
          updated_at: ~U[2020-01-01 00:00:00Z]
        )

      ds2 =
        insert(:data_structure,
          last_change_at: ~U[2020-01-02 00:00:00Z],
          updated_at: ~U[2020-01-02 00:00:00Z]
        )

      ds3 =
        insert(:data_structure,
          last_change_at: ~U[2020-01-03 00:00:00Z],
          updated_at: ~U[2020-01-03 00:00:00Z]
        )

      insert(:data_structure_version,
        data_structure_id: ds1.id,
        deleted_at: ~U[2020-01-03 00:00:00Z],
        updated_at: ~U[2020-01-01 00:00:00Z],
        version: 1
      )

      insert(:data_structure_version,
        data_structure_id: ds1.id,
        deleted_at: ~U[2020-01-03 00:00:00Z],
        updated_at: ~U[2020-01-01 00:00:00Z],
        version: 2
      )

      insert(:data_structure_version,
        data_structure_id: ds2.id,
        deleted_at: ~U[2020-01-02 00:00:00Z],
        updated_at: ~U[2020-01-02 00:00:00Z],
        version: 1
      )

      insert(:data_structure_version,
        data_structure_id: ds3.id,
        deleted_at: ~U[2020-01-01 00:00:00Z],
        updated_at: ~U[2020-01-03 00:00:00Z],
        version: 1
      )

      result = DataStructures.list_data_structure_metrics(%{since: since}, 0, 10)

      assert length(result) == 2
      assert Enum.map(result, & &1.id) |> Enum.sort() == [ds2.id, ds3.id] |> Enum.sort()
    end

    test "filters by since clause only considers latest version" do
      since = ~U[2020-01-02 00:00:00Z]

      ds1 =
        insert(:data_structure,
          last_change_at: ~U[2020-01-03 00:00:00Z],
          updated_at: ~U[2020-01-03 00:00:00Z]
        )

      ds2 =
        insert(:data_structure,
          last_change_at: ~U[2020-01-01 00:00:00Z],
          updated_at: ~U[2020-01-01 00:00:00Z]
        )

      insert(:data_structure_version,
        name: "error dsv1",
        data_structure_id: ds1.id,
        deleted_at: ~U[2020-01-01 00:00:00Z],
        updated_at: ~U[2020-01-01 00:00:00Z],
        version: 1
      )

      insert(:data_structure_version,
        name: "dsv1",
        data_structure_id: ds1.id,
        deleted_at: ~U[2020-01-03 00:00:00Z],
        updated_at: ~U[2020-01-03 00:00:00Z],
        version: 2
      )

      insert(:data_structure_version,
        name: "error dsv2",
        data_structure_id: ds2.id,
        deleted_at: ~U[2020-01-01 00:00:00Z],
        updated_at: ~U[2020-01-01 00:00:00Z],
        version: 1
      )

      result = DataStructures.list_data_structure_metrics(%{since: since}, 0, 10)

      assert length(result) == 1
      assert [result_ds] = result
      assert result_ds.id == ds1.id
      assert result_ds.name == "dsv1"
    end

    test "orders results by id ascending" do
      ds3 = insert(:data_structure)
      ds1 = insert(:data_structure)
      ds2 = insert(:data_structure)

      insert(:data_structure_version,
        data_structure_id: ds3.id,
        deleted_at: ~U[2020-01-03 00:00:00Z]
      )

      insert(:data_structure_version,
        data_structure_id: ds1.id,
        deleted_at: ~U[2020-01-01 00:00:00Z]
      )

      insert(:data_structure_version,
        data_structure_id: ds2.id,
        deleted_at: ~U[2020-01-02 00:00:00Z]
      )

      result = DataStructures.list_data_structure_metrics(%{}, 0, 10)

      assert length(result) == 3
      ids = Enum.map(result, & &1.id)
      assert ids == Enum.sort(ids)
    end

    test "only considers latest version when multiple versions exist" do
      ds1 = insert(:data_structure, last_change_at: ~U[2020-01-01 00:00:00Z])
      ds2 = insert(:data_structure, last_change_at: ~U[2020-01-02 00:00:00Z])

      insert(:data_structure_version,
        data_structure_id: ds1.id,
        deleted_at: ~U[2020-01-01 00:00:00Z],
        version: 1
      )

      insert(:data_structure_version,
        data_structure_id: ds1.id,
        deleted_at: nil,
        name: "dsv1",
        version: 2
      )

      insert(:data_structure_version,
        data_structure_id: ds2.id,
        deleted_at: nil,
        version: 1
      )

      insert(:data_structure_version,
        data_structure_id: ds2.id,
        deleted_at: ~U[2020-01-02 00:00:00Z],
        name: "dsv2",
        version: 2
      )

      result = DataStructures.list_data_structure_metrics(%{}, 0, 10)

      assert length(result) == 2
      [result_ds1, result_ds2] = Enum.sort_by(result, & &1.id)
      assert result_ds1.id == ds1.id
      assert result_ds2.id == ds2.id
      assert result_ds1.name == "dsv1"
      assert result_ds2.name == "dsv2"
    end

    test "returns empty list when since filter excludes all deleted structures" do
      since = ~U[2020-01-05 00:00:00Z]

      ds1 = insert(:data_structure, updated_at: ~U[2020-01-01 00:00:00Z])
      ds2 = insert(:data_structure, updated_at: ~U[2020-01-02 00:00:00Z])

      insert(:data_structure_version,
        data_structure_id: ds1.id,
        deleted_at: ~U[2020-01-01 00:00:00Z],
        updated_at: ~U[2020-01-01 00:00:00Z]
      )

      insert(:data_structure_version,
        data_structure_id: ds2.id,
        deleted_at: ~U[2020-01-02 00:00:00Z],
        updated_at: ~U[2020-01-02 00:00:00Z]
      )

      result = DataStructures.list_data_structure_metrics(%{since: since}, 0, 10)

      assert result == []
    end

    test "handles pagination at boundary correctly" do
      ds1 = insert(:data_structure)
      ds2 = insert(:data_structure)
      ds3 = insert(:data_structure)

      insert(:data_structure_version,
        data_structure_id: ds1.id,
        deleted_at: ~U[2020-01-01 00:00:00Z]
      )

      insert(:data_structure_version,
        data_structure_id: ds2.id,
        deleted_at: ~U[2020-01-02 00:00:00Z]
      )

      insert(:data_structure_version,
        data_structure_id: ds3.id,
        deleted_at: ~U[2020-01-03 00:00:00Z]
      )

      page0 = DataStructures.list_data_structure_metrics(%{}, 0, 3)
      page1 = DataStructures.list_data_structure_metrics(%{}, 1, 3)

      assert length(page0) == 3
      assert page1 == []
    end

    test "returns parent data_structure_id for structures with parent relation" do
      parent_ds = insert(:data_structure)

      parent_dsv =
        insert(:data_structure_version,
          data_structure_id: parent_ds.id,
          name: "parent"
        )

      child_ds = insert(:data_structure)

      child_dsv =
        insert(:data_structure_version,
          data_structure_id: child_ds.id,
          name: "child"
        )

      insert(:data_structure_relation,
        parent_id: parent_dsv.id,
        child_id: child_dsv.id,
        relation_type_id: RelationTypes.default_id!()
      )

      orphan_ds = insert(:data_structure)

      insert(:data_structure_version,
        data_structure_id: orphan_ds.id,
        name: "orphan"
      )

      result = DataStructures.list_data_structure_metrics(%{}, 0, 10)

      child_row = Enum.find(result, &(&1.id == child_ds.id))
      orphan_row = Enum.find(result, &(&1.id == orphan_ds.id))

      assert child_row.parent_id == parent_ds.id
      assert orphan_row.parent_id == nil
    end

    test "merges mutable metadata into metadata" do
      ds = insert(:data_structure)

      insert(:data_structure_version,
        data_structure_id: ds.id,
        metadata: %{"type" => "varchar", "size" => "100"}
      )

      insert(:structure_metadata,
        data_structure_id: ds.id,
        fields: %{"custom_field" => "custom_value", "size" => "200"},
        version: 0
      )

      [row] = DataStructures.list_data_structure_metrics(%{}, 0, 10)

      assert row.metadata["type"] == "varchar"
      assert row.metadata["custom_field"] == "custom_value"
      assert row.metadata["size"] == "200"
    end

    test "metadata without mutable metadata returns only version metadata" do
      ds = insert(:data_structure)

      insert(:data_structure_version,
        data_structure_id: ds.id,
        metadata: %{"type" => "varchar"}
      )

      [row] = DataStructures.list_data_structure_metrics(%{}, 0, 10)

      assert row.metadata == %{"type" => "varchar"}
    end

    test "ignores mutable metadata whose lifetime does not overlap with the version" do
      ds = insert(:data_structure)

      insert(:data_structure_version,
        data_structure_id: ds.id,
        metadata: %{"type" => "varchar"},
        inserted_at: ~U[2020-06-01 00:00:00Z]
      )

      insert(:structure_metadata,
        data_structure_id: ds.id,
        fields: %{"extra" => "value"},
        version: 0,
        inserted_at: ~U[2020-01-01 00:00:00Z],
        deleted_at: ~U[2020-03-01 00:00:00Z]
      )

      [row] = DataStructures.list_data_structure_metrics(%{}, 0, 10)

      assert row.metadata == %{"type" => "varchar"}
      refute Map.has_key?(row.metadata, "extra")
    end
  end

  describe "count_metrics_data_structures" do
    test "returns count matching list length" do
      ds1 = insert(:data_structure, last_change_at: ~U[2020-01-01 00:00:00Z])
      ds2 = insert(:data_structure, last_change_at: ~U[2020-01-02 00:00:00Z])
      ds3 = insert(:data_structure, last_change_at: ~U[2020-01-03 00:00:00Z])
      ds4 = insert(:data_structure, last_change_at: ~U[2020-01-04 00:00:00Z])

      insert(:data_structure_version,
        data_structure_id: ds1.id,
        deleted_at: ~U[2020-01-02 00:00:00Z]
      )

      insert(:data_structure_version,
        data_structure_id: ds2.id,
        deleted_at: ~U[2020-01-03 00:00:00Z]
      )

      insert(:data_structure_version,
        data_structure_id: ds3.id,
        deleted_at: ~U[2020-01-04 00:00:00Z]
      )

      insert(:data_structure_version, data_structure_id: ds4.id, deleted_at: nil)

      list_result = DataStructures.list_data_structure_metrics(%{}, 0, 10)
      count_result = DataStructures.count_metrics_data_structures(%{})

      assert count_result == length(list_result)
      assert count_result == 4
    end

    test "returns zero when no structures exist" do
      count_result = DataStructures.count_metrics_data_structures(%{})

      assert count_result == 0
    end

    test "filters by since clause" do
      since = ~U[2020-01-03 00:00:00Z]

      ds1 =
        insert(:data_structure,
          last_change_at: ~U[2020-01-01 00:00:00Z],
          updated_at: ~U[2020-01-01 00:00:00Z]
        )

      ds2 =
        insert(:data_structure,
          last_change_at: ~U[2020-01-02 00:00:00Z],
          updated_at: ~U[2020-01-02 00:00:00Z]
        )

      ds3 =
        insert(:data_structure,
          last_change_at: ~U[2020-01-03 00:00:00Z],
          updated_at: ~U[2020-01-03 00:00:00Z]
        )

      ds4 =
        insert(:data_structure,
          last_change_at: ~U[2020-01-04 00:00:00Z],
          updated_at: ~U[2020-01-04 00:00:00Z]
        )

      insert(:data_structure_version,
        data_structure_id: ds1.id,
        deleted_at: ~U[2020-01-02 00:00:00Z],
        updated_at: ~U[2020-01-01 00:00:00Z]
      )

      insert(:data_structure_version,
        data_structure_id: ds2.id,
        deleted_at: ~U[2020-01-03 00:00:00Z],
        updated_at: ~U[2020-01-02 00:00:00Z]
      )

      insert(:data_structure_version,
        data_structure_id: ds3.id,
        deleted_at: ~U[2020-01-04 00:00:00Z],
        updated_at: ~U[2020-01-03 00:00:00Z]
      )

      insert(:data_structure_version,
        data_structure_id: ds4.id,
        deleted_at: nil,
        updated_at: ~U[2020-01-04 00:00:00Z]
      )

      list_result = DataStructures.list_data_structure_metrics(%{since: since}, 0, 10)
      count_result = DataStructures.count_metrics_data_structures(%{since: since})

      assert count_result == length(list_result)
      assert count_result == 2
    end

    test "returns zero when since filter excludes all" do
      since = ~U[2020-01-05 00:00:00Z]

      ds1 =
        insert(:data_structure,
          last_change_at: ~U[2020-01-01 00:00:00Z],
          updated_at: ~U[2020-01-01 00:00:00Z]
        )

      ds2 =
        insert(:data_structure,
          last_change_at: ~U[2020-01-02 00:00:00Z],
          updated_at: ~U[2020-01-02 00:00:00Z]
        )

      insert(:data_structure_version,
        data_structure_id: ds1.id,
        deleted_at: ~U[2020-01-01 00:00:00Z],
        updated_at: ~U[2020-01-01 00:00:00Z]
      )

      insert(:data_structure_version,
        data_structure_id: ds2.id,
        deleted_at: ~U[2020-01-02 00:00:00Z],
        updated_at: ~U[2020-01-02 00:00:00Z]
      )

      count_result = DataStructures.count_metrics_data_structures(%{since: since})

      assert count_result == 0
    end

    test "count is consistent with paginated list results" do
      ds1 = insert(:data_structure, last_change_at: ~U[2020-01-01 00:00:00Z])
      ds2 = insert(:data_structure, last_change_at: ~U[2020-01-02 00:00:00Z])
      ds3 = insert(:data_structure, last_change_at: ~U[2020-01-03 00:00:00Z])

      insert(:data_structure_version, data_structure_id: ds1.id)
      insert(:data_structure_version, data_structure_id: ds2.id)
      insert(:data_structure_version, data_structure_id: ds3.id)

      count_result = DataStructures.count_metrics_data_structures(%{})
      page0 = DataStructures.list_data_structure_metrics(%{}, 0, 2)
      page1 = DataStructures.list_data_structure_metrics(%{}, 1, 2)

      assert count_result == 3
      assert length(page0) + length(page1) == count_result
    end
  end
end
