defmodule TdDd.Grants.BulkLoadTest do
  use TdDd.DataCase

  alias TdDd.Grants
  alias TdDd.Grants.BulkLoad
  alias TdDd.Grants.Grant

  @moduletag sandbox: :shared

  setup do
    start_supervised!(TdDd.Search.StructureEnricher)
    %{id: user_id_1} = CacheHelpers.insert_user()
    %{id: user_id_2} = CacheHelpers.insert_user()

    [
      user_id_1: user_id_1,
      user_id_2: user_id_2,
      source_user_name_1: "source_user_name_#{user_id_1}",
      source_user_name_2: "source_user_name_#{user_id_2}",
      claims: build(:claims)
    ]
  end

  describe "bulk_load/2" do
    setup :create_data_structure

    @tag authentication: [role: "admin"]
    test "create grants when data is valid", %{
      data_structure_1: %{id: structure_id_1, external_id: data_structure_external_id_1},
      data_structure_2: %{id: structure_id_2, external_id: data_structure_external_id_2},
      user_id_1: user_id_1,
      user_id_2: user_id_2,
      source_user_name_1: source_user_name_1,
      source_user_name_2: source_user_name_2,
      claims: claims
    } do
      grants = [
        %{
          "op" => "add",
          "detail" => %{},
          "end_date" => Date.utc_today() |> Date.add(1),
          "start_date" => "2010-04-17",
          "data_structure_external_id" => data_structure_external_id_1,
          "user_id" => user_id_1,
          "source_user_name" => source_user_name_1
        },
        %{
          "op" => "add",
          "detail" => %{},
          "end_date" => Date.utc_today() |> Date.add(1),
          "start_date" => "2010-04-17",
          "data_structure_external_id" => data_structure_external_id_2,
          "user_id" => user_id_2,
          "source_user_name" => source_user_name_2
        }
      ]

      assert {:ok, [id1, id2]} = BulkLoad.bulk_load(claims, grants)

      assert length(Grants.list_grants([])) == 2

      assert %Grant{id: ^id1, data_structure_id: ^structure_id_1} = Grants.get_grant!(id1)
      assert %Grant{id: ^id2, data_structure_id: ^structure_id_2} = Grants.get_grant!(id2)
    end

    @tag authentication: [role: "admin"]
    test "return error when one of the external_id is not valid", %{
      data_structure_1: %{external_id: data_structure_external_id_1},
      user_id_1: user_id_1,
      user_id_2: user_id_2,
      source_user_name_1: source_user_name_1,
      source_user_name_2: source_user_name_2,
      claims: claims
    } do
      grants = [
        %{
          "op" => "add",
          "detail" => %{},
          "end_date" => Date.utc_today(),
          "start_date" => "2010-04-17",
          "data_structure_external_id" => data_structure_external_id_1,
          "user_id" => user_id_1,
          "source_user_name" => source_user_name_1
        },
        %{
          "op" => "add",
          "detail" => %{},
          "end_date" => Date.utc_today(),
          "start_date" => "2010-04-17",
          "data_structure_external_id" => "zoo",
          "user_id" => user_id_2,
          "source_user_name" => source_user_name_2
        }
      ]

      assert {:error, {:not_found, "DataStructure"}} = BulkLoad.bulk_load(claims, grants)

      assert [] = Grants.list_grants([])
    end

    @tag authentication: [role: "admin"]
    test "return error when one of the grants exist", %{
      data_structure_1: %{external_id: data_structure_external_id_1},
      user_id_1: user_id_1,
      source_user_name_1: source_user_name_1,
      claims: claims
    } do
      grants = [
        %{
          "op" => "add",
          "detail" => %{},
          "end_date" => Date.utc_today() |> Date.add(1),
          "start_date" => "2010-04-17",
          "data_structure_external_id" => data_structure_external_id_1,
          "user_id" => user_id_1,
          "source_user_name" => source_user_name_1
        }
      ]

      assert assert {:ok, [_]} = BulkLoad.bulk_load(claims, grants)

      assert assert {:error, %Ecto.Changeset{}} = BulkLoad.bulk_load(claims, grants)

      assert length(Grants.list_grants([])) == 1
    end

    @tag authentication: [role: "admin"]
    test "return error when the user does not exist.", %{
      data_structure_1: %{external_id: data_structure_external_id_1},
      user_id_1: user_id_1,
      source_user_name_1: source_user_name_1,
      claims: claims
    } do
      grants = [
        %{
          "op" => "add",
          "detail" => %{},
          "end_date" => Date.utc_today(),
          "start_date" => "2010-04-17",
          "data_structure_external_id" => data_structure_external_id_1,
          "user_id" => user_id_1,
          "source_user_name" => source_user_name_1
        },
        %{
          "op" => "add",
          "detail" => %{},
          "end_date" => Date.utc_today(),
          "start_date" => "2010-04-17",
          "data_structure_external_id" => data_structure_external_id_1,
          "user_id" => 1_111_111,
          "source_user_name" => "source_user_name_1111111"
        }
      ]

      assert {:error, %Ecto.Changeset{}} = BulkLoad.bulk_load(claims, grants)

      assert [] == Grants.list_grants([])
    end
  end

  defp create_data_structure(_) do
    [data_structure_1: insert(:data_structure), data_structure_2: insert(:data_structure)]
  end
end
