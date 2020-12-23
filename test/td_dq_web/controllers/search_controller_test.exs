defmodule TdDqWeb.SearchControllerTest do
  use TdDqWeb.ConnCase

  alias TdDq.Permissions.MockPermissionResolver

  setup_all do
    start_supervised!(MockPermissionResolver)
    :ok
  end

  describe "index" do
    @tag :admin_authenticated
    test "search empty rules", %{conn: conn} do
      conn = post(conn, Routes.search_path(conn, :search_rules))
      assert json_response(conn, 200)["data"] == []
    end

    @tag :admin_authenticated
    test "search non empty rules", %{conn: conn} do
      insert(:rule)
      conn = post(conn, Routes.search_path(conn, :search_rules))
      assert length(json_response(conn, 200)["data"]) == 1
    end

    @tag :admin_authenticated
    test "search implementations", %{conn: conn} do
      implementation = insert(:implementation)
      conn = post(conn, Routes.search_path(conn, :search_implementations))
      assert [_ | _] = response = json_response(conn, 200)["data"]
      assert Enum.any?(response, fn %{"id" => id} -> id == implementation.id end)
    end

    @tag authenticated_user: "not_an_admin"
    test "list implementations depending on permissions", %{conn: conn, user: %{id: user_id}} do
      concept_1 = "1"
      concept_2 = "2"
      domain1_view = 1
      domain2_execute = 2

      creation_attrs_1 = %{
        business_concept_id: concept_1,
        description: %{"document" => "some description"},
        goal: 42,
        minimum: 42,
        name: "some name 1",
        updated_by: Integer.mod(:binary.decode_unsigned("app-admin"), 100_000)
      }

      creation_attrs_2 = %{
        business_concept_id: concept_2,
        description: %{"document" => "some description"},
        goal: 42,
        minimum: 42,
        name: "some name 2",
        updated_by: Integer.mod(:binary.decode_unsigned("app-admin"), 100_000)
      }

      insert(:implementation, rule: build(:rule, creation_attrs_1))
      insert(:implementation, rule: build(:rule, creation_attrs_2))

      create_acl_entry(user_id, concept_1, domain1_view, [domain1_view], "view")
      create_acl_entry(user_id, concept_2, domain1_view, [domain1_view], "view")

      conn =
        post(conn, Routes.search_path(conn, :search_implementations), %{
          "filters" => %{}
        })

      assert length(json_response(conn, 200)["data"]) == 2

      assert json_response(conn, 200)["user_permissions"] == %{
               "execute" => false,
               "manage" => true
             }

      create_acl_entry(user_id, concept_2, domain2_execute, [domain2_execute], "execute_view")

      conn =
        post(conn, Routes.search_path(conn, :search_implementations), %{
          "filters" => %{}
        })

      assert length(json_response(conn, 200)["data"]) == 2

      assert json_response(conn, 200)["user_permissions"] == %{
               "execute" => true,
               "manage" => true
             }
    end
  end

  defp create_acl_entry(user_id, bc_id, domain_id, domain_ids, role) do
    MockPermissionResolver.create_hierarchy(bc_id, domain_ids)

    MockPermissionResolver.create_acl_entry(%{
      principal_id: user_id,
      principal_type: "user",
      resource_id: domain_id,
      resource_type: "domain",
      role_name: role
    })
  end
end
