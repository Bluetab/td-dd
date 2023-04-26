defmodule TdDqWeb.ImplementationStructureControllerTest do
  use TdDqWeb.ConnCase

  import TdDd.TestOperators

  alias TdDd.Search.MockIndexWorker

  setup %{conn: conn} do
    start_supervised!(MockIndexWorker)
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "create implementation_structure" do
    @tag authentication: [role: "admin"]
    test "renders implementation_structure when data is valid", %{conn: conn} do
      %{id: implementation_id} = implementation = insert(:implementation)
      %{id: data_structure_id} = insert(:data_structure)

      conn =
        post(
          conn,
          Routes.implementation_implementation_structure_path(conn, :create, implementation),
          data_structure_id: data_structure_id,
          type: "dataset"
        )

      assert response(conn, 201)

      assert %{
               "data" => %{
                 "data_structures" => [
                   %{
                     "type" => "dataset",
                     "data_structure" => %{
                       "id" => ^data_structure_id
                     }
                   }
                 ]
               }
             } =
               conn
               |> get(Routes.implementation_path(conn, :show, implementation_id))
               |> json_response(:ok)
    end

    @tag authentication: [
           user_name: "non_admin",
           permissions: [
             :link_implementation_structure,
             :view_quality_rule,
             :link_data_structure,
             :view_data_structure
           ]
         ]
    test "users with permission can create ImplementationStructure link", %{
      conn: conn,
      domain: domain
    } do
      %{id: implementation_id} = implementation = insert(:implementation, domain_id: domain.id)
      %{id: data_structure_id} = insert(:data_structure, domain_ids: [domain.id])

      conn =
        post(
          conn,
          Routes.implementation_implementation_structure_path(conn, :create, implementation),
          data_structure_id: data_structure_id,
          type: "dataset"
        )

      assert response(conn, 201)

      assert %{
               "data" => %{
                 "data_structures" => [
                   %{
                     "type" => "dataset",
                     "data_structure" => %{
                       "id" => ^data_structure_id
                     }
                   }
                 ]
               }
             } =
               conn
               |> get(Routes.implementation_path(conn, :show, implementation_id))
               |> json_response(:ok)
    end

    @tag authentication: [
           user_name: "non_admin",
           permissions: [:link_data_structure]
         ]
    test "users without permission on implementation cannot create ImplementationStructure link",
         %{conn: conn, domain: domain} do
      implementation = insert(:implementation, domain_id: domain.id)
      %{id: data_structure_id} = insert(:data_structure, domain_ids: [domain.id])

      conn =
        post(
          conn,
          Routes.implementation_implementation_structure_path(conn, :create, implementation),
          data_structure_id: data_structure_id,
          type: "dataset"
        )

      assert response(conn, :forbidden)
    end

    @tag authentication: [
           user_name: "non_admin",
           permissions: [:link_implementation_structure]
         ]
    test "users without permission on structure cannot create ImplementationStructure link", %{
      conn: conn,
      domain: domain
    } do
      implementation = insert(:implementation, domain_id: domain.id)
      %{id: data_structure_id} = insert(:data_structure, domain_ids: [domain.id])

      conn =
        post(
          conn,
          Routes.implementation_implementation_structure_path(conn, :create, implementation),
          data_structure_id: data_structure_id,
          type: "dataset"
        )

      assert response(conn, :forbidden)
    end

    @tag authentication: [role: "admin"]
    test "reindex implementation after create ImplementationStructure link", %{
      conn: conn
    } do
      MockIndexWorker.clear()
      domain = build(:domain)
      %{id: implementation_ref_id} = insert(:implementation, version: 1)

      %{id: implementation_id} =
        implementation =
        insert(:implementation, version: 2, implementation_ref: implementation_ref_id)

      %{id: data_structure_id} = insert(:data_structure, domain_ids: [domain.id])

      conn =
        post(
          conn,
          Routes.implementation_implementation_structure_path(conn, :create, implementation),
          data_structure_id: data_structure_id,
          type: "dataset"
        )

      assert response(conn, 201)

      [
        {:reindex_implementations, implementation_reindexed}
      ] = MockIndexWorker.calls()

      assert implementation_reindexed <|> [implementation_id, implementation_ref_id]
    end

    @tag authentication: [role: "admin"]
    test "create structure link for implementation ref", %{
      conn: conn
    } do
      domain = build(:domain)

      %{id: implementation_ref_id} =
        insert(
          :implementation,
          domain_id: domain.id,
          version: 1,
          status: :versioned
        )

      implementation =
        insert(
          :implementation,
          domain_id: domain.id,
          version: 2,
          status: :published,
          implementation_ref: implementation_ref_id
        )

      %{id: data_structure_id} = insert(:data_structure, domain_ids: [domain.id])

      conn =
        post(
          conn,
          Routes.implementation_implementation_structure_path(conn, :create, implementation),
          data_structure_id: data_structure_id,
          type: "dataset"
        )

      assert response(conn, 201)

      assert %{
               "data" => %{
                 "data_structures" => [
                   %{
                     "type" => "dataset",
                     "data_structure" => %{
                       "id" => ^data_structure_id
                     }
                   }
                 ]
               }
             } =
               conn
               |> get(Routes.implementation_path(conn, :show, implementation_ref_id))
               |> json_response(:ok)
    end

    @tag authentication: [role: "admin"]
    test "renders error when type is invalid", %{conn: conn} do
      implementation = insert(:implementation)
      %{id: data_structure_id} = insert(:data_structure)

      conn =
        post(
          conn,
          Routes.implementation_implementation_structure_path(conn, :create, implementation),
          data_structure_id: data_structure_id,
          type: "invalid"
        )

      assert %{"errors" => %{"type" => ["is invalid"]}} = json_response(conn, 422)
    end

    @tag authentication: [role: "admin"]
    test "renders error when data_structure does not exist", %{conn: conn} do
      implementation = insert(:implementation)

      conn =
        post(
          conn,
          Routes.implementation_implementation_structure_path(conn, :create, implementation),
          data_structure_id: 0,
          type: "dataset"
        )

      assert response(conn, 404)
    end

    @tag authentication: [role: "admin"]
    test "renders error when implementation does not exist", %{conn: conn} do
      %{id: data_structure_id} = insert(:data_structure)

      implementation =
        insert(:implementation)
        |> Map.put(:id, 0)

      conn =
        post(
          conn,
          Routes.implementation_implementation_structure_path(conn, :create, implementation),
          data_structure_id: data_structure_id,
          type: "dataset"
        )

      assert response(conn, 404)
    end
  end

  describe "delete implementation_structure" do
    @tag authentication: [role: "admin"]
    test "deletes chosen implementation_structure", %{conn: conn} do
      %{
        id: id,
        implementation_id: implementation_id
      } = insert(:implementation_structure)

      conn =
        delete(
          conn,
          Routes.implementation_structure_path(
            conn,
            :delete,
            id
          )
        )

      assert response(conn, 204)

      assert %{
               "data" => %{"data_structures" => []}
             } =
               conn
               |> get(Routes.implementation_path(conn, :show, implementation_id))
               |> json_response(:ok)
    end

    @tag authentication: [role: "admin"]
    test "deletes implementation_structure with same structure and implementation and different type",
         %{conn: conn} do
      %{
        id: id,
        implementation_id: implementation_id,
        data_structure_id: data_structure_id
      } = insert(:implementation_structure, type: "population")

      insert(:implementation_structure,
        implementation_id: implementation_id,
        data_structure_id: data_structure_id,
        type: "validation"
      )

      conn =
        delete(
          conn,
          Routes.implementation_structure_path(
            conn,
            :delete,
            id
          )
        )

      assert response(conn, 204)

      assert %{
               "data" => %{
                 "data_structures" => [
                   %{
                     "implementation_id" => ^implementation_id,
                     "data_structure_id" => ^data_structure_id,
                     "type" => "validation"
                   }
                 ]
               }
             } =
               conn
               |> get(Routes.implementation_path(conn, :show, implementation_id))
               |> json_response(:ok)
    end

    @tag authentication: [
           user_name: "non_admin",
           permissions: [:link_implementation_structure, :view_quality_rule, :view_data_structure]
         ]
    test "user with permission can delete", %{conn: conn, domain: domain} do
      %{
        id: id,
        implementation_id: implementation_id
      } =
        insert(:implementation_structure,
          implementation: build(:implementation, domain_id: domain.id),
          data_structure: build(:data_structure, domain_ids: [domain.id])
        )

      conn =
        delete(
          conn,
          Routes.implementation_structure_path(
            conn,
            :delete,
            id
          )
        )

      assert response(conn, 204)

      assert %{
               "data" => %{"data_structures" => []}
             } =
               conn
               |> get(Routes.implementation_path(conn, :show, implementation_id))
               |> json_response(:ok)
    end

    @tag authentication: [
           user_name: "non_admin",
           permissions: [:view_quality_rule, :view_data_structure]
         ]
    test "user without permission cannot delete", %{conn: conn, domain: domain} do
      %{id: id, implementation_id: implementation_id} =
        insert(:implementation_structure,
          implementation: build(:implementation, domain_id: domain.id),
          data_structure: build(:data_structure, domain_ids: [domain.id])
        )

      conn =
        delete(
          conn,
          Routes.implementation_structure_path(
            conn,
            :delete,
            id
          )
        )

      assert response(conn, :forbidden)

      assert %{
               "data" => %{
                 "data_structures" => [
                   %{"id" => ^id}
                 ]
               }
             } =
               conn
               |> get(Routes.implementation_path(conn, :show, implementation_id))
               |> json_response(:ok)
    end

    @tag authentication: [role: "admin"]
    test "reindex implementation after delete ImplementationStructure link", %{
      conn: conn
    } do
      MockIndexWorker.clear()
      domain = build(:domain)

      %{id: implementation_ref_id} = implementation_ref = insert(:implementation, version: 1)

      %{id: implementation_id} =
        insert(:implementation, version: 2, implementation_ref: implementation_ref_id)

      %{id: id} =
        insert(:implementation_structure,
          implementation: implementation_ref,
          data_structure: build(:data_structure, domain_ids: [domain.id])
        )

      conn =
        delete(
          conn,
          Routes.implementation_structure_path(
            conn,
            :delete,
            id
          )
        )

      assert response(conn, 204)

      [
        {:reindex_implementations, implementation_reindexed}
      ] = MockIndexWorker.calls()

      assert implementation_reindexed <|> [implementation_id, implementation_ref_id]
    end
  end
end
