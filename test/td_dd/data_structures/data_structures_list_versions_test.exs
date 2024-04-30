defmodule TdDd.DataStructuresTestListVersions do
  use TdDd.DataStructureCase

  alias TdDd.DataStructures

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
end
