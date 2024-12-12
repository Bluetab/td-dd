defmodule TdDdWeb.StructureTagSearchControllerTest do
  use TdDdWeb.ConnCase

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

  describe("search/2") do
    @tag authentication: [role: "service"]
    test("with no params returns all items", %{
      conn: conn,
      tag_ids: [structure_tag_id_1, structure_tag_id_2, structure_tag_id_3, structure_tag_id_4]
    }) do
      %{"data" => data} =
        conn
        |> post(Routes.structure_tag_search_path(conn, :search))
        |> json_response(:ok)

      assert [structure_tag_id_1, structure_tag_id_2, structure_tag_id_3, structure_tag_id_4] ==
               Enum.map(data, &Map.get(&1, "id"))

      assert %{
               "id" => _,
               "comment" => _,
               "data_structure_id" => _,
               "tag_id" => _,
               "inserted_at" => _,
               "updated_at" => _
             } = List.first(data)
    end

    @tag authentication: [role: "service"]
    test("with since param returns updated_at after date", %{
      conn: conn,
      tag_ids: [structure_tag_id_1, _structure_tag_id_2, structure_tag_id_3, structure_tag_id_4],
      four_days_ago: four_days_ago
    }) do
      params = %{"since" => NaiveDateTime.to_string(four_days_ago)}

      assert [structure_tag_id_3, structure_tag_id_4, structure_tag_id_1] ==
               conn
               |> post(Routes.structure_tag_search_path(conn, :search, params))
               |> json_response(:ok)
               |> Map.get("data")
               |> Enum.map(&Map.get(&1, "id"))
    end

    @tag authentication: [role: "service"]
    test("with min_id param returns grater or equal ids", %{
      conn: conn,
      tag_ids: [_structure_tag_id_1, _structure_tag_id_2, structure_tag_id_3, structure_tag_id_4]
    }) do
      params = %{"min_id" => structure_tag_id_3}

      assert [structure_tag_id_3, structure_tag_id_4] ==
               conn
               |> post(Routes.structure_tag_search_path(conn, :search, params))
               |> json_response(:ok)
               |> Map.get("data")
               |> Enum.map(&Map.get(&1, "id"))
    end

    @tag authentication: [role: "service"]
    test("with since, min_id and size params returns filtered results", %{
      conn: conn,
      tag_ids: [_structure_tag_id_1, structure_tag_id_2, structure_tag_id_3, _structure_tag_id_4],
      four_days_ago: four_days_ago
    }) do
      params = %{
        "since" => NaiveDateTime.to_string(four_days_ago),
        "min_id" => structure_tag_id_2,
        "size" => 1
      }

      assert [structure_tag_id_3] ==
               conn
               |> post(Routes.structure_tag_search_path(conn, :search, params))
               |> json_response(:ok)
               |> Map.get("data")
               |> Enum.map(&Map.get(&1, "id"))
    end

    @tag authentication: [role: "service"]
    test("not allowed param will be omited", %{
      conn: conn,
      tag_ids: [structure_tag_id_1, structure_tag_id_2, structure_tag_id_3, structure_tag_id_4]
    }) do
      params = %{"anything" => false}

      assert [structure_tag_id_1, structure_tag_id_2, structure_tag_id_3, structure_tag_id_4] ==
               conn
               |> post(Routes.structure_tag_search_path(conn, :search, params))
               |> json_response(:ok)
               |> Map.get("data")
               |> Enum.map(&Map.get(&1, "id"))
    end

    test("Unauthenticated user cannot get data", %{conn: conn}) do
      Enum.map(1..3, fn _ ->
        %{id: id} = insert(:structure_tag)
        id
      end)

      assert conn
             |> post(Routes.structure_tag_search_path(conn, :search))
             |> json_response(401)
    end
  end
end
