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
  end
end
