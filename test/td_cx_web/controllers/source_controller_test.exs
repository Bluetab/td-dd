defmodule TdCxWeb.SourceControllerTest.K8sMock do
  use ExUnit.Case

  import TdCx.K8s.Factory

  def request(
        :get,
        "https://k8smock/apis/batch/v1beta1/namespaces/default/cronjobs",
        _,
        _headers,
        opts
      ) do
    assert Keyword.get(opts, :params) == %{
             labelSelector: "truedat.io/connector-engine=app-admin,truedat.io/launch-type=manual"
           }

    body =
      :list
      |> build(%{"items" => [build(:cron_job)]})
      |> Jason.encode!()

    {:ok, %HTTPoison.Response{status_code: 200, body: body}}
  end
end

defmodule TdCxWeb.SourceControllerTest do
  use TdCxWeb.ConnCase

  alias K8s.Client.DynamicHTTPProvider
  alias TdCx.Cache.SourceLoader
  alias TdCx.Permissions.MockPermissionResolver
  alias TdCx.Sources
  alias TdCx.Sources.Source

  setup_all do
    {:ok, _pid} = start_supervised(MockPermissionResolver)
    {:ok, _pid} = start_supervised(SourceLoader)
    :ok
  end

  setup do
    {:ok, pid} = start_supervised({TdCx.K8s, Application.get_env(:td_cx, TdCx.K8s, [])})
    {:ok, _} = start_supervised(DynamicHTTPProvider)
    DynamicHTTPProvider.register(pid, __MODULE__.K8sMock)
    :ok
  end

  @app_admin_template %{
    id: 1,
    name: "app-admin",
    label: "app-admin",
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

  @create_attrs %{
    "config" => %{"a" => "1"},
    "external_id" => "some external_id",
    "type" => "app-admin",
    "active" => true
  }
  @update_attrs %{
    "config" => %{"a" => "3"},
    "external_id" => "some external_id",
    "type" => "some updated type",
    "active" => false
  }
  @invalid_update_attrs %{
    "config" => %{"b" => "1"},
    "external_id" => "some external_id",
    "type" => "some updated type"
  }
  @invalid_attrs %{
    "config" => nil,
    "external_id" => "some external_id",
    "secrets_key" => nil,
    "type" => nil
  }

  def fixture(:source) do
    {:ok, source} = Sources.create_source(@create_attrs)
    source
  end

  def fixture(:template) do
    {:ok, template} = Templates.create_template(@app_admin_template)
    template
  end

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    setup [:create_source]

    @tag :admin_authenticated
    test "lists all sources", %{conn: conn} do
      assert %{"data" => data} =
               conn
               |> get(Routes.source_path(conn, :index, type: "app-admin"))
               |> json_response(:ok)

      assert [
               %{
                 "config" => %{"a" => "1"},
                 "external_id" => "some external_id",
                 "id" => _id,
                 "type" => "app-admin",
                 "active" => true
               }
             ] = data
    end
  end

  describe "show" do
    setup [:create_source]

    @tag :admin_authenticated
    test "show source", %{conn: conn} do
      assert %{"data" => data} =
               conn
               |> get(Routes.source_path(conn, :show, "some external_id"))
               |> json_response(:ok)

      assert %{
               "id" => _id,
               "external_id" => "some external_id",
               "active" => true,
               "type" => "app-admin",
               "config" => %{"a" => "1"},
               "job_types" => ["Metadata"]
             } = data
    end
  end

  describe "create source" do
    @tag authenticated_user: "non_admin_user"
    test "returns unauthorized for non admin user", %{conn: conn} do
      conn = post(conn, Routes.source_path(conn, :create), source: @create_attrs)
      assert %{"errors" => %{"detail" => "Forbidden"}} = json_response(conn, 403)
    end

    @tag :admin_authenticated
    test "renders source when data is valid", %{conn: conn} do
      Templates.create_template(@app_admin_template)

      assert %{"data" => data} =
               conn
               |> post(Routes.source_path(conn, :create), source: @create_attrs)
               |> json_response(:created)

      assert %{
               "id" => _id,
               "config" => %{"a" => "1"},
               "external_id" => "some external_id",
               "type" => "app-admin",
               "active" => true
             } = data
    end

    @tag :admin_authenticated
    test "renders errors when data is invalid", %{conn: conn} do
      Templates.create_template(@app_admin_template)
      conn = post(conn, Routes.source_path(conn, :create), source: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update source" do
    setup [:create_source]

    @tag authenticated_user: "non_admin_user"
    test "returns unauthorized for non admin user", %{
      conn: conn,
      source: %Source{external_id: external_id}
    } do
      conn = put(conn, Routes.source_path(conn, :update, external_id), source: @update_attrs)
      assert %{"errors" => %{"detail" => "Forbidden"}} = json_response(conn, 403)
    end

    @tag :admin_authenticated
    test "renders source when data is valid", %{
      conn: conn,
      source: %Source{external_id: external_id}
    } do
      assert %{"data" => data} =
               conn
               |> put(Routes.source_path(conn, :update, external_id), source: @update_attrs)
               |> json_response(:ok)

      assert %{
               "id" => _id,
               "config" => %{"a" => "3"},
               "external_id" => ^external_id,
               "type" => "app-admin",
               "active" => false
             } = data
    end

    @tag :admin_authenticated
    test "renders errors when template content is invalid", %{
      conn: conn,
      source: %Source{external_id: external_id}
    } do
      conn =
        put(conn, Routes.source_path(conn, :update, external_id), source: @invalid_update_attrs)

      assert json_response(conn, 422)["errors"] == %{"a" => ["can't be blank"]}
    end

    @tag :admin_authenticated
    test "renders errors when data is invalid", %{conn: conn, source: source} do
      conn =
        put(conn, Routes.source_path(conn, :update, source.external_id), source: @invalid_attrs)

      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete source" do
    setup [:create_source]

    @tag authenticated_user: "non_admin_user"
    test "returns unauthorized for non admin user", %{conn: conn, source: source} do
      conn = delete(conn, Routes.source_path(conn, :delete, source.external_id))
      assert %{"errors" => %{"detail" => "Forbidden"}} = json_response(conn, 403)
    end

    @tag :admin_authenticated
    test "deletes chosen source", %{conn: conn, source: source} do
      conn = delete(conn, Routes.source_path(conn, :delete, source.external_id))
      assert response(conn, 204)

      conn = get(conn, Routes.source_path(conn, :show, source.external_id))
      assert response(conn, 404)
    end
  end

  defp create_source(_) do
    Templates.create_template(@app_admin_template)
    source = fixture(:source)
    {:ok, source: source}
  end
end
