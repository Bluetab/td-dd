defmodule TdDd.StructureTagsTest do
  use TdDdWeb.ConnCase

  alias TdDd.DataStructures.StructureTags

  setup do
    now = NaiveDateTime.local_now()
    five_days_ago = NaiveDateTime.add(now, -5, :day)
    three_days_ago = NaiveDateTime.add(now, -3, :day)
    one_day_ago = NaiveDateTime.add(now, -1, :day)

    %{id: structure_tag_id_1} = insert(:structure_tag, updated_at: now)
    %{id: structure_tag_id_2} = insert(:structure_tag, updated_at: five_days_ago)
    %{id: structure_tag_id_3} = insert(:structure_tag, updated_at: three_days_ago)
    %{id: structure_tag_id_4} = insert(:structure_tag, updated_at: one_day_ago)

    {:ok,
     tag_ids: [structure_tag_id_1, structure_tag_id_2, structure_tag_id_3, structure_tag_id_4],
     four_days_ago: NaiveDateTime.add(now, -4, :day)}
  end

  describe("list_structure_tags/1") do
    test("with no params returns all items", %{
      tag_ids: [structure_tag_id_1, structure_tag_id_2, structure_tag_id_3, structure_tag_id_4]
    }) do
      assert [structure_tag_id_1, structure_tag_id_2, structure_tag_id_3, structure_tag_id_4] ==
               %{}
               |> StructureTags.list_structure_tags()
               |> Enum.map(&Map.get(&1, :id))
    end

    test("with since param returns updated_at after date", %{
      tag_ids: [structure_tag_id_1, _structure_tag_id_2, structure_tag_id_3, structure_tag_id_4],
      four_days_ago: four_days_ago
    }) do
      params = %{since: NaiveDateTime.to_string(four_days_ago)}

      assert [structure_tag_id_3, structure_tag_id_4, structure_tag_id_1] ==
               params
               |> StructureTags.list_structure_tags()
               |> Enum.map(&Map.get(&1, :id))
    end

    test("with min_id param returns grater or equal ids", %{
      tag_ids: [_structure_tag_id_1, _structure_tag_id_2, structure_tag_id_3, structure_tag_id_4]
    }) do
      params = %{min_id: structure_tag_id_3}

      assert [structure_tag_id_3, structure_tag_id_4] ==
               params
               |> StructureTags.list_structure_tags()
               |> Enum.map(&Map.get(&1, :id))
    end

    test("with since, min_id and size params returns filtered results", %{
      tag_ids: [_structure_tag_id_1, structure_tag_id_2, structure_tag_id_3, _structure_tag_id_4],
      four_days_ago: four_days_ago
    }) do
      params = %{
        since: NaiveDateTime.to_string(four_days_ago),
        min_id: structure_tag_id_2,
        size: 1
      }

      assert [structure_tag_id_3] ==
               params
               |> StructureTags.list_structure_tags()
               |> Enum.map(&Map.get(&1, :id))
    end

    test("not allowed param will be omited", %{
      tag_ids: [structure_tag_id_1, structure_tag_id_2, structure_tag_id_3, structure_tag_id_4]
    }) do
      params = %{anything: false}

      assert [structure_tag_id_1, structure_tag_id_2, structure_tag_id_3, structure_tag_id_4] ==
               params
               |> StructureTags.list_structure_tags()
               |> Enum.map(&Map.get(&1, :id))
    end
  end
end
