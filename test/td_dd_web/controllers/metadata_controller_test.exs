defmodule TdDdWeb.MetadataControllerTest do
  use TdDdWeb.ConnCase
  use PhoenixSwagger.SchemaTest, "priv/static/swagger.json"

  alias TdCache.TaxonomyCache
  alias TdDd.DataStructures.PathCache
  alias TdDd.Lineage.GraphData
  alias TdDd.Loader.LoaderWorker
  alias TdDd.Permissions.MockPermissionResolver
  alias TdDd.Search.MockIndexWorker
  alias TdDdWeb.ApiServices.MockTdAuditService
  alias TdDdWeb.ApiServices.MockTdAuthService

  @import_dir Application.get_env(:td_dd, :import_dir)

  setup_all do
    start_supervised(MockIndexWorker)
    start_supervised(MockTdAuditService)
    start_supervised(MockTdAuthService)
    start_supervised(MockPermissionResolver)
    start_supervised(LoaderWorker)
    start_supervised(PathCache)
    start_supervised(GraphData)
    :ok
  end

  setup %{fixture: fixture} do
    on_exit(fn ->
      ["nodes.csv", "rels.csv"]
      |> Enum.map(&Path.join([@import_dir, &1]))
      |> Enum.each(&File.rm/1)
    end)

    params =
      %{
        structures: "structures.csv",
        fields: "fields.csv",
        relations: "relations.csv",
        nodes: "nodes.csv",
        rels: "rels.csv"
      }
      |> Enum.map(fn {k, v} -> {k, Path.join([fixture, v])} end)
      |> Enum.filter(fn {_, v} -> File.exists?(v) end)
      |> Map.new(fn {k, v} -> {k, %Plug.Upload{path: v, filename: Path.basename(v)}} end)

    {:ok, params}
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
    @tag fixture: "test/fixtures/metadata/relation_type"
    test "uploads structure, field and relation with relation_type_name metadata", %{
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
      insert(:relation_type, name: "relation_type_1")

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
      structure_json_response = json_response(conn, 200)["data"]
      assert length(structure_json_response["parents"]) == 1
      assert length(structure_json_response["siblings"]) == 4
      assert length(structure_json_response["children"]) == 16

      relation_parent_id = get_id(json_response, "Dashboard Gobierno y Calidad v1")
      conn = get(conn, Routes.data_structure_path(conn, :show, relation_parent_id))
      json_response = json_response(conn, 200)["data"]
      assert json_response["parents"] == []
      assert length(json_response["children"]) == 4
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

  describe "data lineage metadata upload" do
    @tag :admin_authenticated
    @tag fixture: "test/fixtures/lineage"
    test "uploads nodes and relations metadata", %{conn: conn, nodes: nodes, rels: rels} do
      refute File.exists?(Path.join([@import_dir, "nodes.csv"]))
      refute File.exists?(Path.join([@import_dir, "rels.csv"]))

      conn = post(conn, Routes.metadata_path(conn, :upload), nodes: nodes, rels: rels)
      assert response(conn, 202) =~ ""
      assert File.exists?(Path.join([@import_dir, "nodes.csv"]))
      assert File.exists?(Path.join([@import_dir, "rels.csv"]))
    end

    @tag :admin_authenticated
    @tag fixture: "test/fixtures/lineage"
    test "uploads nodes metadata", %{conn: conn, nodes: nodes} do
      refute File.exists?(Path.join([@import_dir, "nodes.csv"]))
      conn = post(conn, Routes.metadata_path(conn, :upload), nodes: nodes)
      assert response(conn, 202) =~ ""
      assert File.exists?(Path.join([@import_dir, "nodes.csv"]))
    end

    @tag :admin_authenticated
    @tag fixture: "test/fixtures/lineage"
    test "uploads relations metadata", %{conn: conn, rels: rels} do
      refute File.exists?(Path.join([@import_dir, "rels.csv"]))
      conn = post(conn, Routes.metadata_path(conn, :upload), rels: rels)
      assert response(conn, 202) =~ ""
      assert File.exists?(Path.join([@import_dir, "rels.csv"]))
    end
  end

  defp get_id(json, name) do
    json
    |> Enum.find(&(&1["name"] == name))
    |> Map.get("id")
  end
end
