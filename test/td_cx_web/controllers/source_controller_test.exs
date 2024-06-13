defmodule TdCxWeb.SourceControllerTest do
  use TdCxWeb.ConnCase

  alias TdCx.Sources
  alias TdCx.Sources.Source
  alias TdDd.Repo

  @template %{
    id: 1,
    name: "foo_type",
    label: "foo_type",
    scope: "cx",
    content: [
      %{
        "name" => "New Group 1",
        "fields" => [
          %{
            "name" => "a",
            "type" => "string",
            "label" => "a",
            "widget" => "string",
            "cardinality" => "1"
          }
        ]
      }
    ]
  }

  @template_multiple %{
    id: 2,
    name: "multiple_fields",
    label: "multiple_fields",
    scope: "cx",
    content: [
      %{
        "name" => "New Group 1",
        "fields" => [
          %{
            "name" => "a",
            "type" => "string",
            "label" => "a",
            "widget" => "string",
            "cardinality" => "1"
          },
          %{
            "name" => "b",
            "type" => "string",
            "label" => "b",
            "widget" => "string",
            "cardinality" => "1"
          }
        ]
      },
      %{
        "name" => "secret_group",
        "fields" => [
          %{
            "name" => "c",
            "type" => "string",
            "label" => "c",
            "widget" => "string",
            "cardinality" => "1"
          }
        ],
        "is_secret" => true
      }
    ]
  }

  @create_attrs %{
    "config" => %{"a" => %{"value" => "1", "origin" => "user"}},
    "external_id" => "some external_id",
    "type" => "foo_type",
    "active" => true
  }
  @update_attrs %{
    "config" => %{"a" => %{"value" => "3", "origin" => "user"}},
    "external_id" => "some external_id",
    "type" => "some updated type",
    "active" => false
  }
  @invalid_update_attrs %{
    "config" => %{"b" => %{"value" => "1", "origin" => "user"}},
    "external_id" => "some external_id",
    "type" => "some updated type"
  }
  @invalid_attrs %{
    "config" => nil,
    "external_id" => "some external_id",
    "secrets_key" => nil,
    "type" => nil
  }

  setup do
    CacheHelpers.insert_template(@template_multiple)
    [template: CacheHelpers.insert_template(@template)]
  end

  describe "GET /api/sources" do
    @tag authentication: [role: "admin"]
    test "admin can list all sources", %{conn: conn} do
      insert(:source, type: "foo_type")
      insert(:source, type: "bar_type")

      assert %{"data" => [_, _]} =
               conn
               |> get(Routes.source_path(conn, :index))
               |> json_response(:ok)
    end

    @tag authentication: [role: "service", user_name: "foo_type"]
    test "service account can list all sources", %{conn: conn} do
      insert(:source, type: "foo_type")
      insert(:source, type: "bar_type")

      assert %{"data" => [_, _]} =
               conn
               |> get(Routes.source_path(conn, :index))
               |> json_response(:ok)
    end

    @tag authentication: [role: "user", permissions: [:manage_raw_quality_rule_implementations]]
    test "user account with manage_raw_quality_rule_implementations permission can list all sources",
         %{conn: conn} do
      insert(:source, type: "foo_type")
      insert(:source, type: "bar_type")

      assert %{"data" => [_, _]} =
               conn
               |> get(Routes.source_path(conn, :index))
               |> json_response(:ok)
    end
  end

  describe "show" do
    setup :create_source

    @tag authentication: [role: "admin"]
    test "show source", %{conn: conn} do
      assert %{"data" => data} =
               conn
               |> get(Routes.source_path(conn, :show, "some external_id"))
               |> json_response(:ok)

      assert %{
               "id" => _id,
               "external_id" => "some external_id",
               "active" => true,
               "type" => "foo_type",
               "config" => %{"a" => %{"value" => "1", "origin" => "user"}}
             } = data
    end

    @tag authentication: [role: "service"]
    test "service account can view source", %{conn: conn} do
      assert %{"data" => data} =
               conn
               |> get(Routes.source_path(conn, :show, "some external_id"))
               |> json_response(:ok)

      assert %{
               "id" => _id,
               "external_id" => "some external_id",
               "active" => true,
               "type" => "foo_type",
               "config" => %{"a" => %{"value" => "1", "origin" => "user"}}
             } = data
    end

    @tag authentication: [role: "admin"]
    test "renders not found for invalid external_id", %{conn: conn} do
      conn = get(conn, Routes.source_path(conn, :show, "invalid_external_id"))

      assert json_response(conn, 404)["errors"] != %{}
    end
  end

  describe "create source" do
    @tag authentication: [role: "user"]
    test "returns unauthorized for non admin user", %{conn: conn} do
      conn = post(conn, Routes.source_path(conn, :create), source: @create_attrs)
      assert %{"errors" => %{"detail" => "Forbidden"}} = json_response(conn, 403)
    end

    @tag authentication: [role: "admin"]
    test "renders source when data is valid", %{conn: conn} do
      external_id = "exid"
      attrs = Map.put(@create_attrs, "external_id", external_id)

      assert %{"data" => data} =
               conn
               |> post(Routes.source_path(conn, :create), source: attrs)
               |> json_response(:created)

      assert %{
               "id" => id,
               "config" => %{"a" => %{"value" => "1", "origin" => "user"}},
               "external_id" => ^external_id,
               "type" => "foo_type",
               "active" => true
             } = data

      attrs =
        attrs
        |> Map.merge(@update_attrs)
        |> Map.put("external_id", external_id)
        |> Map.put("type", "foo_type")

      assert %{"errors" => %{"external_id" => ["has already been taken"]}} =
               conn
               |> post(Routes.source_path(conn, :create), source: attrs)
               |> json_response(:unprocessable_entity)

      Source
      |> Repo.get(id)
      |> Source.changeset(%{deleted_at: DateTime.utc_now()})
      |> Repo.update()

      assert %{"data" => data} =
               conn
               |> post(Routes.source_path(conn, :create), source: attrs)
               |> json_response(:created)

      assert %{
               "id" => ^id,
               "config" => %{"a" => %{"value" => "3", "origin" => "user"}},
               "external_id" => ^external_id,
               "type" => "foo_type",
               "active" => false
             } = data
    end

    @tag authentication: [role: "admin"]
    test "renders errors when data is invalid", %{conn: conn} do
      assert %{"errors" => %{} = errors} =
               conn
               |> post(Routes.source_path(conn, :create), source: @invalid_attrs)
               |> json_response(:unprocessable_entity)

      refute errors == %{}
    end
  end

  describe "update only one field" do
    @tag authentication: [role: "admin"]
    test "renders source when data is valid", %{conn: conn} do
      create_attrs = %{
        "config" => %{
          "a" => %{"value" => "1", "origin" => "user"},
          "b" => %{"value" => "2", "origin" => "user"},
          "c" => %{"value" => "3", "origin" => "user"}
        },
        "external_id" => "some external_id",
        "type" => "multiple_fields",
        "active" => true
      }

      {:ok, %Source{external_id: external_id}} = Sources.create_source(create_attrs)
      source_config = %{"b" => %{"value" => "foo", "origin" => "user"}}

      assert %{"data" => data} =
               conn
               |> put(Routes.source_path(conn, :update, external_id), source_config: source_config)
               |> json_response(:ok)

      assert %{
               "id" => _id,
               "config" => %{
                 "a" => %{"value" => "1", "origin" => "user"},
                 "b" => %{"value" => "foo", "origin" => "user"}
               },
               "external_id" => ^external_id,
               "type" => "multiple_fields",
               "active" => true
             } = data
    end
  end

  describe "update source" do
    setup :create_source

    @tag authentication: [role: "user"]
    test "returns unauthorized for non admin user", %{
      conn: conn,
      source: %{external_id: external_id}
    } do
      assert %{"errors" => %{} = errors} =
               conn
               |> put(Routes.source_path(conn, :update, external_id), source: @update_attrs)
               |> json_response(:forbidden)

      refute errors == %{}
    end

    @tag authentication: [role: "admin"]
    test "renders source when data is valid", %{
      conn: conn,
      source: %Source{external_id: external_id, type: type}
    } do
      source = Map.put(@update_attrs, "type", type)

      assert %{"data" => data} =
               conn
               |> put(Routes.source_path(conn, :update, external_id), source: source)
               |> json_response(:ok)

      assert %{
               "id" => _id,
               "config" => %{"a" => %{"value" => "3", "origin" => "user"}},
               "external_id" => ^external_id,
               "type" => "foo_type",
               "active" => false
             } = data
    end

    @tag authentication: [role: "admin"]
    test "renders errors when template content is invalid", %{
      conn: conn,
      source: %Source{external_id: external_id, type: type}
    } do
      source = Map.put(@invalid_update_attrs, "type", type)
      conn = put(conn, Routes.source_path(conn, :update, external_id), source: source)

      assert json_response(conn, 422)["errors"] == %{"a" => ["can't be blank"]}
    end

    @tag authentication: [role: "admin"]
    test "renders errors when data is invalid", %{conn: conn, source: source} do
      conn =
        put(conn, Routes.source_path(conn, :update, source.external_id), source: @invalid_attrs)

      assert json_response(conn, 422)["errors"] != %{}
    end

    @tag authentication: [role: "admin"]
    test "renders not found for invalid external_id", %{conn: conn} do
      conn =
        put(conn, Routes.source_path(conn, :update, "invalid_external_id"), source: @update_attrs)

      assert json_response(conn, 404)["errors"] != %{}
    end
  end

  describe "delete source" do
    setup :create_source

    setup do
      start_supervised!(TdCx.Cache.SourcesLatestEvent)
      :ok
    end

    @tag authentication: [role: "user"]
    test "returns unauthorized for non admin user", %{conn: conn, source: source} do
      conn = delete(conn, Routes.source_path(conn, :delete, source.external_id))
      assert %{"errors" => %{"detail" => "Forbidden"}} = json_response(conn, 403)
    end

    @tag authentication: [role: "admin"]
    test "deletes chosen source", %{conn: conn, source: source} do
      conn = delete(conn, Routes.source_path(conn, :delete, source.external_id))
      assert response(conn, 204)

      conn = get(conn, Routes.source_path(conn, :show, source.external_id))
      assert response(conn, 404)
    end
  end

  defp create_source(_) do
    {:ok, source} = Sources.create_source(@create_attrs)
    [source: source]
  end
end
