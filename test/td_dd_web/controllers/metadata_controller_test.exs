defmodule TdDdWeb.MetadataControllerTest do
  use TdDdWeb.ConnCase
  use PhoenixSwagger.SchemaTest, "priv/static/swagger.json"

  alias TdDd.Loader.LoaderWorker
  alias TdDd.MockTaxonomyCache
  alias TdDd.Permissions.MockPermissionResolver
  alias TdDd.Search.MockIndexWorker
  alias TdDdWeb.ApiServices.MockTdAuditService
  alias TdDdWeb.ApiServices.MockTdAuthService
  alias TdPerms.MockDynamicFormCache

  setup_all do
    start_supervised(MockIndexWorker)
    start_supervised(MockTdAuditService)
    start_supervised(MockTdAuthService)
    start_supervised(MockTaxonomyCache)
    start_supervised(MockPermissionResolver)
    start_supervised(MockDynamicFormCache)
    :ok
  end

  setup %{fixture: fixture} do
    structures = %Plug.Upload{path: fixture <> "/structures.csv"}
    fields = %Plug.Upload{path: fixture <> "/fields.csv"}
    relations = %Plug.Upload{path: fixture <> "/relations.csv"}

    {:ok, structures: structures, fields: fields, relations: relations}
  end

  describe "upload" do
    @tag :admin_authenticated
    @tag fixture: "test/fixtures/metadata"
    test "uploads structure, field and relation metadata", %{
      conn: conn,
      structures: structures,
      fields: fields,
      relations: relations
    } do
      conn =
        post(conn, Routes.system_path(conn, :create),
          system: %{name: "Power BI", external_id: "pbi"}
        )

      assert %{"id" => _} = json_response(conn, 201)["data"]

      conn =
        post(conn, Routes.metadata_path(conn, :upload),
          data_structures: structures,
          data_fields: fields,
          data_structure_relations: relations
        )

      assert response(conn, 202) =~ ""

      # waits for loader to complete
      LoaderWorker.ping()

      search_params = %{ou: "Truedat"}
      conn = get(conn, Routes.data_structure_path(conn, :index, search_params))
      json_response = json_response(conn, 200)["data"]
      assert length(json_response) == 5 + 68

      structure_id = get_id(json_response, "Calidad")
      conn = get(conn, Routes.data_structure_path(conn, :show, structure_id))
      json_response = json_response(conn, 200)["data"]
      assert length(json_response["parents"]) == 1
      assert length(json_response["siblings"]) == 4
      assert length(json_response["data_fields"]) == 16
    end
  end

  defp get_id(json, name) do
    json
    |> Enum.find(&(&1["name"] == name))
    |> Map.get("id")
  end

  describe "upload datastructures and datafields with versions" do
    @tag :admin_authenticated
    @tag fixture: "test/fixtures/metadata"
    test "uploads structure, field with versions", %{conn: conn} do

      filepath = "test/fixtures/metadata/versions"
      structures = %Plug.Upload{path: filepath <> "/structures.csv"}
      fields = %Plug.Upload{path: filepath <> "/fields.csv"}

      conn =
        post(conn, Routes.system_path(conn, :create),
          system: %{name: "MicroTest", external_id: "imd_615"}
        )

      assert %{"id" => _} = json_response(conn, 201)["data"]

      conn =
        post(conn, Routes.metadata_path(conn, :upload),
          data_structures: structures,
          data_fields: fields
      )

      assert response(conn, 202) =~ ""

      # waits for loader to complete
      LoaderWorker.ping()

      search_params = %{ou: "Truedat"}
      conn = get(conn, Routes.data_structure_path(conn, :index, search_params))
      json_response = json_response(conn, 200)["data"]

      structure_id = get_id(json_response, "spike_prueba")
      conn = get(conn, Routes.data_structure_path(conn, :show, structure_id))
      json_response = json_response(conn, 200)["data"]

      assert length(json_response["children"]) == 1
      assert json_response["parents"] == []
    end
  end
end
