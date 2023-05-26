defmodule TdDd.DataStructures.HierarchyTest do
  use TdDd.DataStructureCase

  import TdDd.TestOperators

  alias TdDd.DataStructures.Hierarchy

  describe "update_hierarchy/1" do
    test "it appends new versions", %{} do
      [
        dsv_id_a,
        dsv_id_b,
        dsv_id_c
      ] =
        dsv_ids =
        ["A", "B", "C"]
        |> create_hierarchy()
        |> Enum.map(& &1.id)

      Hierarchy.update_hierarchy(dsv_ids)

      expected = [
        %Hierarchy{dsv_id: dsv_id_a, ancestor_dsv_id: dsv_id_a, ancestor_level: 0},
        %Hierarchy{dsv_id: dsv_id_b, ancestor_dsv_id: dsv_id_b, ancestor_level: 0},
        %Hierarchy{dsv_id: dsv_id_b, ancestor_dsv_id: dsv_id_a, ancestor_level: 1},
        %Hierarchy{dsv_id: dsv_id_c, ancestor_dsv_id: dsv_id_c, ancestor_level: 0},
        %Hierarchy{dsv_id: dsv_id_c, ancestor_dsv_id: dsv_id_b, ancestor_level: 1},
        %Hierarchy{dsv_id: dsv_id_c, ancestor_dsv_id: dsv_id_a, ancestor_level: 2}
      ]

      assert expected ||| Hierarchy.list_hierarchy()

      [
        dsv_id_x,
        dsv_id_y,
        dsv_id_z
      ] =
        dsv_ids =
        ["X", "Y", "Z"]
        |> create_hierarchy()
        |> Enum.map(& &1.id)

      Hierarchy.update_hierarchy(dsv_ids)

      expected =
        expected ++
          [
            %Hierarchy{dsv_id: dsv_id_x, ancestor_dsv_id: dsv_id_x, ancestor_level: 0},
            %Hierarchy{dsv_id: dsv_id_y, ancestor_dsv_id: dsv_id_y, ancestor_level: 0},
            %Hierarchy{dsv_id: dsv_id_y, ancestor_dsv_id: dsv_id_x, ancestor_level: 1},
            %Hierarchy{dsv_id: dsv_id_z, ancestor_dsv_id: dsv_id_z, ancestor_level: 0},
            %Hierarchy{dsv_id: dsv_id_z, ancestor_dsv_id: dsv_id_y, ancestor_level: 1},
            %Hierarchy{dsv_id: dsv_id_z, ancestor_dsv_id: dsv_id_x, ancestor_level: 2}
          ]

      assert expected ||| Hierarchy.list_hierarchy()
    end

    test "it should not insert duplicates", %{} do
      [
        dsv_id_a,
        dsv_id_b,
        dsv_id_c
      ] =
        dsv_ids =
        ["A", "B", "C"]
        |> create_hierarchy()
        |> Enum.map(& &1.id)

      Hierarchy.update_hierarchy(dsv_ids)
      Hierarchy.update_hierarchy(dsv_ids)

      expected = [
        %Hierarchy{dsv_id: dsv_id_a, ancestor_dsv_id: dsv_id_a, ancestor_level: 0},
        %Hierarchy{dsv_id: dsv_id_b, ancestor_dsv_id: dsv_id_b, ancestor_level: 0},
        %Hierarchy{dsv_id: dsv_id_b, ancestor_dsv_id: dsv_id_a, ancestor_level: 1},
        %Hierarchy{dsv_id: dsv_id_c, ancestor_dsv_id: dsv_id_c, ancestor_level: 0},
        %Hierarchy{dsv_id: dsv_id_c, ancestor_dsv_id: dsv_id_b, ancestor_level: 1},
        %Hierarchy{dsv_id: dsv_id_c, ancestor_dsv_id: dsv_id_a, ancestor_level: 2}
      ]

      assert expected ||| Hierarchy.list_hierarchy()
    end
  end
end
