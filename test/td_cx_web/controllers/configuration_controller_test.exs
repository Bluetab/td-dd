defmodule TdCxWeb.ConfigurationControllerTest do
  use TdCxWeb.ConnCase

  alias TdCx.Configurations.Configuration
  alias TdCx.Permissions.MockPermissionResolver

  setup_all do
    start_supervised(MockPermissionResolver)
    :ok
  end

  @test_template %{
    id: 5,
    name: "config",
    label: "config",
    scope: "ca",
    content: [
      %{
        "name" => "Group 1",
        "fields" => [
          %{
            "name" => "field1",
            "type" => "string",
            "label" => "Multiple 1",
            "values" => nil,
            "cardinality" => "1"
          }
        ]
      }
    ]
  }

  @secret_template %{
    id: 7,
    name: "secret_config",
    label: "secret_config",
    scope: "ca",
    content: [
      %{
        "name" => "Group 1",
        "fields" => [
          %{
            "name" => "field1",
            "type" => "string",
            "label" => "Multiple 1",
            "values" => nil,
            "cardinality" => "1"
          }
        ]
      },
      %{
        "name" => "secret_group",
        "is_secret" => true,
        "fields" => [
          %{
            "name" => "secret_field",
            "type" => "string",
            "label" => "Secret",
            "values" => nil,
            "cardinality" => "1"
          }
        ]
      }
    ]
  }
  @another_template %{
    id: 6,
    name: "another_config",
    label: "another_config",
    scope: "ca",
    content: []
  }

  @create_attrs %{
    content: %{"field1" => "value"},
    external_id: "some external_id",
    type: "config"
  }

  @update_attrs %{
    content: %{"field1" => "updated value"},
    external_id: "external_id"
  }

  @invalid_update_attrs %{
    content: %{"non_existent" => "field"}
  }

  describe "index" do
    setup [:create_configuration]
    setup [:create_another_configuration]
    setup [:create_secret_configuration]

    @tag authenticated_user: "non_admin_user"
    test "lists all configurations", %{conn: conn} do
      conn = get(conn, Routes.configuration_path(conn, :index))

      assert [
               %{
                 "content" => %{"field1" => "value"},
                 "external_id" => "external_id",
                 "type" => "config"
               },
               %{
                 "content" => %{},
                 "external_id" => "another_external_id",
                 "type" => "another_config"
               },
               %{
                 "content" => %{"field1" => "value", "secret_field" => "secret value"},
                 "external_id" => "secret_external_id",
                 "type" => "secret_config"
               }
             ] = json_response(conn, 200)["data"]
    end

    @tag authenticated_user: "non_admin_user"
    test "lists only configurations", %{conn: conn} do
      conn = get(conn, Routes.configuration_path(conn, :index, type: "config"))

      assert [
               %{
                 "content" => %{"field1" => "value"},
                 "external_id" => "external_id",
                 "type" => "config"
               }
             ] = json_response(conn, 200)["data"]
    end
  end

  describe "show" do
    setup [:create_configuration]
    setup [:create_secret_configuration]

    @tag authenticated_user: "non_admin_user"
    test "show configuration", %{conn: conn} do
      conn = get(conn, Routes.configuration_path(conn, :show, "external_id"))

      assert %{
               "content" => %{"field1" => "value"},
               "external_id" => "external_id",
               "type" => "config"
             } = json_response(conn, 200)["data"]
    end

    @tag :admin_authenticated
    test "show configuration with secrets", %{conn: conn} do
      conn = get(conn, Routes.configuration_path(conn, :show, "secret_external_id"))

      assert %{
               "content" => %{"field1" => "value", "secret_field" => "secret value"},
               "external_id" => "secret_external_id",
               "type" => "secret_config"
             } = json_response(conn, 200)["data"]
    end
  end

  describe "create" do
    setup [:create_template]

    @tag :admin_authenticated
    test "creates a new configuration", %{conn: conn} do
      conn = post(conn, Routes.configuration_path(conn, :create), configuration: @create_attrs)
      assert %{"external_id" => external_id, "id" => id} = json_response(conn, 201)["data"]

      conn = get(conn, Routes.configuration_path(conn, :show, external_id))

      assert %{
               "id" => ^id,
               "content" => %{"field1" => "value"},
               "external_id" => ^external_id,
               "type" => "config",
               "secrets_key" => nil
             } = json_response(conn, 200)["data"]
    end

    @tag authenticated_user: "non_admin_user"
    test "configuration creation forbidden to non admin users", %{conn: conn} do
      conn = post(conn, Routes.configuration_path(conn, :create), configuration: @create_attrs)
      assert %{"errors" => %{"detail" => "Forbidden"}} = json_response(conn, 403)
    end
  end

  describe "update configuration" do
    setup [:create_configuration]

    @tag authenticated_user: "non_admin_user"
    test "returns unauthorized for non admin user", %{
      conn: conn,
      configuration: %Configuration{external_id: external_id}
    } do
      conn =
        put(conn, Routes.configuration_path(conn, :update, external_id),
          configuration: @update_attrs
        )

      assert %{"errors" => %{"detail" => "Forbidden"}} = json_response(conn, 403)
    end

    @tag :admin_authenticated
    test "renders source when data is valid", %{
      conn: conn,
      configuration: %Configuration{external_id: external_id}
    } do
      conn =
        put(conn, Routes.configuration_path(conn, :update, external_id),
          configuration: @update_attrs
        )

      assert %{"external_id" => ^external_id, "id" => id} = json_response(conn, 200)["data"]

      conn = get(conn, Routes.configuration_path(conn, :show, external_id))

      assert %{
               "id" => ^id,
               "content" => %{"field1" => "updated value"},
               "external_id" => ^external_id,
               "type" => "config",
               "secrets_key" => nil
             } = json_response(conn, 200)["data"]
    end

    @tag :admin_authenticated
    test "renders errors when template content is invalid", %{
      conn: conn,
      configuration: %Configuration{external_id: external_id}
    } do
      conn =
        put(conn, Routes.configuration_path(conn, :update, external_id),
          configuration: @invalid_update_attrs
        )

      assert json_response(conn, 422)["errors"] == %{"content" => ["invalid content"]}
    end
  end

  describe "delete" do
    setup [:create_configuration]

    @tag authenticated_user: "non_admin_user"
    test "returns unauthorized for non admin user", %{conn: conn, configuration: configuration} do
      conn = delete(conn, Routes.configuration_path(conn, :delete, configuration.external_id))
      assert %{"errors" => %{"detail" => "Forbidden"}} = json_response(conn, 403)
    end

    @tag :admin_authenticated
    test "deletes chosen config", %{conn: conn, configuration: configuration} do
      conn = delete(conn, Routes.configuration_path(conn, :delete, configuration.external_id))
      assert response(conn, 204)

      conn = get(conn, Routes.configuration_path(conn, :show, configuration.external_id))
      assert response(conn, 404)
    end
  end

  defp create_configuration(_) do
    create_template(nil)
    configuration = insert(:configuration, content: %{"field1" => "value"})
    {:ok, configuration: configuration}
  end

  defp create_secret_configuration(_) do
    create_secret_template(nil)

    configuration =
      insert(:configuration,
        content: %{"field1" => "value", "secret_field" => "secret value"},
        external_id: "secret_external_id",
        type: "secret_config"
      )

    {:ok, configuration: configuration}
  end

  defp create_another_configuration(_) do
    create_another_template(nil)

    configuration =
      insert(:configuration,
        content: %{},
        external_id: "another_external_id",
        type: "another_config"
      )

    {:ok, configuration: configuration}
  end

  defp create_template(_) do
    template = Templates.create_template(@test_template)
    {:ok, template: template}
  end

  defp create_secret_template(_) do
    template = Templates.create_template(@secret_template)
    {:ok, template: template}
  end

  defp create_another_template(_) do
    template = Templates.create_template(@another_template)
    {:ok, template: template}
  end
end
