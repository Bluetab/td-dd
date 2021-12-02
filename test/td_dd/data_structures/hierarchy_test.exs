defmodule TdDd.DataStructures.HierarchyTest do
  use TdDd.DataStructureCase

  import TdDd.TestOperators

  alias TdDd.DataStructures.Hierarchy


  describe "update_hierarchy/1" do
    test "it appends new versions", %{} do
      [
        dsv_id_A,
        dsv_id_B,
        dsv_id_C
      ] =
        dsv_ids =
        ["A", "B", "C"]
        |> create_hierarchy()
        |> Enum.map(& &1.id)

      Hierarchy.update_hierarchy(dsv_ids)

      expected = [
        %Hierarchy{dsv_id: dsv_id_A, ancestor_dsv_id: dsv_id_A, ancestor_level: 0},
        %Hierarchy{dsv_id: dsv_id_B, ancestor_dsv_id: dsv_id_B, ancestor_level: 0},
        %Hierarchy{dsv_id: dsv_id_B, ancestor_dsv_id: dsv_id_A, ancestor_level: 1},
        %Hierarchy{dsv_id: dsv_id_C, ancestor_dsv_id: dsv_id_C, ancestor_level: 0},
        %Hierarchy{dsv_id: dsv_id_C, ancestor_dsv_id: dsv_id_B, ancestor_level: 1},
        %Hierarchy{dsv_id: dsv_id_C, ancestor_dsv_id: dsv_id_A, ancestor_level: 2}
      ]

      assert expected <|> Hierarchy.list_hierarchy()


      [
        dsv_id_X,
        dsv_id_Y,
        dsv_id_Z
      ] =
        dsv_ids =
        ["X", "Y", "Z"]
        |> create_hierarchy()
        |> Enum.map(& &1.id)

      Hierarchy.update_hierarchy(dsv_ids)

      expected = expected ++ [
        %Hierarchy{dsv_id: dsv_id_X, ancestor_dsv_id: dsv_id_X, ancestor_level: 0},
        %Hierarchy{dsv_id: dsv_id_Y, ancestor_dsv_id: dsv_id_Y, ancestor_level: 0},
        %Hierarchy{dsv_id: dsv_id_Y, ancestor_dsv_id: dsv_id_X, ancestor_level: 1},
        %Hierarchy{dsv_id: dsv_id_Z, ancestor_dsv_id: dsv_id_Z, ancestor_level: 0},
        %Hierarchy{dsv_id: dsv_id_Z, ancestor_dsv_id: dsv_id_Y, ancestor_level: 1},
        %Hierarchy{dsv_id: dsv_id_Z, ancestor_dsv_id: dsv_id_X, ancestor_level: 2}
      ]

      assert expected <|> Hierarchy.list_hierarchy()
    end

    test "it should not insert duplicates", %{} do
      [
        dsv_id_A,
        dsv_id_B,
        dsv_id_C
      ] =
        dsv_ids =
        ["A", "B", "C"]
        |> create_hierarchy()
        |> Enum.map(& &1.id)

      Hierarchy.update_hierarchy(dsv_ids)
      Hierarchy.update_hierarchy(dsv_ids)

      expected = [
        %Hierarchy{dsv_id: dsv_id_A, ancestor_dsv_id: dsv_id_A, ancestor_level: 0},
        %Hierarchy{dsv_id: dsv_id_B, ancestor_dsv_id: dsv_id_B, ancestor_level: 0},
        %Hierarchy{dsv_id: dsv_id_B, ancestor_dsv_id: dsv_id_A, ancestor_level: 1},
        %Hierarchy{dsv_id: dsv_id_C, ancestor_dsv_id: dsv_id_C, ancestor_level: 0},
        %Hierarchy{dsv_id: dsv_id_C, ancestor_dsv_id: dsv_id_B, ancestor_level: 1},
        %Hierarchy{dsv_id: dsv_id_C, ancestor_dsv_id: dsv_id_A, ancestor_level: 2}
      ]

      assert expected <|> Hierarchy.list_hierarchy()


    end
  end
end
