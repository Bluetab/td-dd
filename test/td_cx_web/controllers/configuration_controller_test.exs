defmodule TdCxWeb.ConfigurationControllerTest do
  use TdCxWeb.ConnCase

  alias TdCx.Configurations
  alias TdCx.Configurations.Configuration

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
    setup [:create_configuration, :create_another_configuration, :create_secret_configuration]

    @tag authentication: [role: "user"]
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

    @tag authentication: [role: "user"]
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
    setup [:create_configuration, :create_secret_configuration]

    @tag authentication: [role: "user"]
    test "show configuration", %{conn: conn} do
      conn = get(conn, Routes.configuration_path(conn, :show, "external_id"))

      assert %{
               "content" => %{"field1" => "value"},
               "external_id" => "external_id",
               "type" => "config"
             } = json_response(conn, 200)["data"]
    end

    @tag authentication: [role: "admin"]
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
    setup :create_template

    @tag authentication: [role: "admin"]
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

    @tag authentication: [role: "user"]
    test "configuration creation forbidden to non admin users", %{conn: conn} do
      conn = post(conn, Routes.configuration_path(conn, :create), configuration: @create_attrs)
      assert %{"errors" => %{"detail" => "Forbidden"}} = json_response(conn, 403)
    end
  end

  describe "update configuration" do
    setup :create_configuration

    @tag authentication: [role: "user"]
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

    @tag authentication: [role: "admin"]
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

    @tag authentication: [role: "admin"]
    test "renders errors when template content is invalid", %{
      conn: conn,
      configuration: %Configuration{external_id: external_id}
    } do
      conn =
        put(conn, Routes.configuration_path(conn, :update, external_id),
          configuration: @invalid_update_attrs
        )

      assert json_response(conn, 422)["errors"] == %{"content" => ["field1: can't be blank"]}
    end
  end

  describe "delete" do
    setup :create_configuration

    @tag authentication: [role: "user"]
    test "returns unauthorized for non admin user", %{conn: conn, configuration: configuration} do
      conn = delete(conn, Routes.configuration_path(conn, :delete, configuration.external_id))
      assert %{"errors" => %{"detail" => "Forbidden"}} = json_response(conn, 403)
    end

    @tag authentication: [role: "admin"]
    test "deletes chosen config", %{conn: conn, configuration: configuration} do
      assert conn
             |> delete(Routes.configuration_path(conn, :delete, configuration.external_id))
             |> response(:no_content)

      assert_error_sent :not_found, fn ->
        get(conn, Routes.configuration_path(conn, :show, configuration.external_id))
      end
    end
  end

  describe "sign" do
    setup do
      secret_key = "foo"

      with_key = %{
        id: System.unique_integer([:positive]),
        name: "foo",
        label: "Foo",
        scope: "ca",
        content: [
          %{
            "name" => "Secret Group",
            "is_secret" => true,
            "fields" => [
              %{
                "name" => "secret_key",
                "type" => "string",
                "label" => "Secret Field",
                "widget" => "password",
                "values" => nil,
                "cardinality" => "?"
              }
            ]
          }
        ]
      }

      without_key = %{
        id: System.unique_integer([:positive]),
        name: "bar",
        label: "Bar",
        scope: "ca",
        content: [
          %{
            "name" => "Secret Group",
            "is_secret" => true,
            "fields" => [
              %{
                "name" => "bar_key",
                "type" => "string",
                "label" => "Secret Field",
                "widget" => "password",
                "values" => nil,
                "cardinality" => "?"
              }
            ]
          }
        ]
      }

      with_key = CacheHelpers.insert_template(with_key)
      without_key = CacheHelpers.insert_template(without_key)

      c1 = build(:configuration, type: with_key.name, content: %{"secret_key" => secret_key})
      c2 = build(:configuration, type: without_key.name)

      {:ok, c1} = Configurations.create_configuration(Map.from_struct(c1))
      {:ok, c2} = Configurations.create_configuration(Map.from_struct(c2))

      [c1: c1, c2: c2, secret_key: secret_key]
    end

    @tag authentication: [role: "user"]
    test "returns signed secret key", %{conn: conn, c1: c1, secret_key: secret_key} do
      now = DateTime.utc_now()
      exp = now |> DateTime.add(10 * 60) |> DateTime.to_unix()

      payload = %{
        "exp" => exp,
        "params" => %{"domain_ids" => [1, 3]},
        "resource" => %{"dashboard" => 1}
      }

      conn =
        post(conn, Routes.configuration_configuration_signer_path(conn, :create, c1.external_id),
          payload: payload
        )

      assert %{"token" => token} = json_response(conn, 201)

      assert {true, %{fields: ^payload}, _} =
               JOSE.JWT.verify_strict(
                 %{"kty" => "oct", "k" => Base.encode64(secret_key)},
                 ["HS256"],
                 token
               )
    end

    @tag authentication: [role: "user"]
    test "returns unauthorized when secrets can not be signed", %{conn: conn, c2: c2} do
      now = DateTime.utc_now()
      exp = now |> DateTime.add(10 * 60) |> DateTime.to_unix()

      payload = %{
        "exp" => exp,
        "params" => %{"domain_ids" => [1, 3]},
        "resource" => %{"dashboard" => 1}
      }

      conn =
        post(conn, Routes.configuration_configuration_signer_path(conn, :create, c2.external_id),
          payload: payload
        )

      assert %{"errors" => %{"detail" => "Unauthorized"}} = json_response(conn, 401)
    end
  end

  defp create_configuration(_) do
    CacheHelpers.insert_template(@test_template)

    [
      configuration:
        insert(:configuration, content: %{"field1" => "value"}, external_id: "external_id")
    ]
  end

  defp create_secret_configuration(_) do
    CacheHelpers.insert_template(@secret_template)

    insert(:configuration,
      content: %{"field1" => "value", "secret_field" => "secret value"},
      external_id: "secret_external_id",
      type: "secret_config"
    )

    :ok
  end

  defp create_another_configuration(_) do
    CacheHelpers.insert_template(@another_template)

    insert(:configuration,
      content: %{},
      external_id: "another_external_id",
      type: "another_config"
    )

    :ok
  end

  defp create_template(_) do
    CacheHelpers.insert_template(@test_template)
    :ok
  end
end
