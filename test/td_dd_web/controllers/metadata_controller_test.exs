defmodule TdDdWeb.MetadataControllerTest do
  use TdDdWeb.ConnCase
  use PhoenixSwagger.SchemaTest, "priv/static/swagger.json"

  alias TdCache.TaxonomyCache
  alias TdDd.DataStructures.PathCache
  alias TdDd.Loader.LoaderWorker
  alias TdDd.Permissions.MockPermissionResolver
  alias TdDd.Search.MockIndexWorker
  alias TdDdWeb.ApiServices.MockTdAuditService
  alias TdDdWeb.ApiServices.MockTdAuthService

  setup_all do
    start_supervised(MockIndexWorker)
    start_supervised(MockTdAuditService)
    start_supervised(MockTdAuthService)
    start_supervised(MockPermissionResolver)
    start_supervised(LoaderWorker)
    start_supervised(PathCache)
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
          data_structures: structures |> Map.put(:filename, "structures"),
          data_fields: fields |> Map.put(:filename, "fields"),
          data_structure_relations: relations |> Map.put(:filename, "relations")
        )

      assert response(conn, 202) =~ ""

      # waits for loader to complete
      LoaderWorker.ping(20_000)

      search_params = %{ou: "Truedat"}
      conn = get(conn, Routes.data_structure_path(conn, :index, search_params))
      json_response = json_response(conn, 200)["data"]
      assert length(json_response) == 5 + 68

      structure_id = get_id(json_response, "Calidad")
      conn = get(conn, Routes.data_structure_path(conn, :show, structure_id))
      json_response = json_response(conn, 200)["data"]
      assert length(json_response["parents"]) == 1
      assert length(json_response["siblings"]) == 4
      assert length(json_response["children"]) == 16
    end

    @tag :admin_authenticated
    @tag fixture: "test/fixtures/metadata"
    test "uploads structure, field and relation metadata whe domain is specified", %{
      conn: conn,
      structures: structures,
      fields: fields,
      relations: relations
    } do
      domain = "Domain1"
      domain_id = 1
      TaxonomyCache.put_domain(%{name: domain, id: domain_id})

      conn =
        post(conn, Routes.system_path(conn, :create),
          system: %{name: "Power BI", external_id: "pbi"}
        )

      assert %{"id" => _} = json_response(conn, 201)["data"]

      conn =
        post(conn, Routes.metadata_path(conn, :upload),
          data_structures: structures |> Map.put(:filename, "structures"),
          data_fields: fields |> Map.put(:filename, "fields"),
          data_structure_relations: relations |> Map.put(:filename, "relations"),
          domain: domain
        )

      assert response(conn, 202) =~ ""

      # waits for loader to complete
      LoaderWorker.ping(20_000)

      search_params = %{ou: domain}
      conn = get(conn, Routes.data_structure_path(conn, :index, search_params))
      json_response = json_response(conn, 200)["data"]
      assert length(json_response) == 5 + 68

      assert Enum.all?(json_response, fn %{"ou" => ou, "domain_id" => id} ->
               id == domain_id && ou == domain
             end)

      structure_id = get_id(json_response, "Calidad")
      conn = get(conn, Routes.data_structure_path(conn, :show, structure_id))
      json_response = json_response(conn, 200)["data"]
      assert length(json_response["parents"]) == 1
      assert length(json_response["siblings"]) == 4
      assert length(json_response["children"]) == 16
    end
  end

  defp get_id(json, name) do
    json
    |> Enum.find(&(&1["name"] == name))
    |> Map.get("id")
  end
end
