defmodule TdDdWeb.MetadataControllerTest do
  use TdDdWeb.ConnCase
  use PhoenixSwagger.SchemaTest, "priv/static/swagger.json"

  import Routes,
    only: [
      data_structure_data_structure_version_path: 4,
      data_structure_path: 2,
      metadata_path: 2
    ]

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
    insert(:system, name: "Power BI", external_id: "pbi")

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
      assert conn
             |> post(metadata_path(conn, :upload),
               data_structures: Map.put(structures, :filename, "structures"),
               data_fields: Map.put(fields, :filename, "fields"),
               data_structure_relations: Map.put(relations, :filename, "relations")
             )
             |> response(:accepted)

      # waits for loader to complete
      LoaderWorker.ping(20_000)

      assert %{"data" => data} =
               conn
               |> get(data_structure_path(conn, :index))
               |> json_response(:ok)

      assert length(data) == 5 + 68

      structure_id = get_id(data, "Calidad")

      assert %{"data" => %{"parents" => parents, "children" => children, "siblings" => siblings}} =
               conn
               |> get(
                 data_structure_data_structure_version_path(conn, :show, structure_id, "latest")
               )
               |> json_response(:ok)

      assert length(parents) == 1
      assert length(siblings) == 4
      assert length(children) == 16
    end

    @tag :admin_authenticated
    @tag fixture: "test/fixtures/metadata/field_external_id"
    test "maintains field_external_id if specified", %{
      conn: conn,
      structures: structures,
      fields: fields
    } do
      assert conn
             |> post(metadata_path(conn, :upload),
               data_structures: Map.put(structures, :filename, "structures"),
               data_fields: Map.put(fields, :filename, "fields")
             )
             |> response(:accepted)

      # waits for loader to complete
      LoaderWorker.ping(20_000)

      assert %{"data" => data} =
               conn
               |> get(data_structure_path(conn, :index))
               |> json_response(:ok)

      external_ids = Enum.map(data, & &1["external_id"])
      assert Enum.member?(external_ids, "parent_external_id")
      assert Enum.member?(external_ids, "parent_external_id/Field1")
      assert Enum.member?(external_ids, "field_with_external_id")
    end

    @tag :admin_authenticated
    @tag fixture: "test/fixtures/metadata/relation_type"
    test "uploads structure, field and relation with relation_type_name metadata", %{
      conn: conn,
      structures: structures,
      fields: fields,
      relations: relations
    } do
      insert(:relation_type, name: "relation_type_1")

      conn =
        post(conn, metadata_path(conn, :upload),
          data_structures: Map.put(structures, :filename, "structures"),
          data_fields: Map.put(fields, :filename, "fields"),
          data_structure_relations: Map.put(relations, :filename, "relations")
        )

      assert response(conn, 202) =~ ""

      # waits for loader to complete
      LoaderWorker.ping(20_000)

      assert %{"data" => data} =
               conn
               |> get(data_structure_path(conn, :index))
               |> json_response(200)

      assert length(data) == 5 + 68

      structure_id = get_id(data, "Calidad")
      relation_parent_id = get_id(data, "Dashboard Gobierno y Calidad v1")

      assert %{"data" => data} =
               conn
               |> get(
                 data_structure_data_structure_version_path(conn, :show, structure_id, "latest")
               )
               |> json_response(200)

      assert length(data["parents"]) == 1
      assert length(data["siblings"]) == 3
      assert length(data["children"]) == 16

      assert %{"data" => %{"parents" => parents, "children" => children}} =
               conn
               |> get(
                 data_structure_data_structure_version_path(
                   conn,
                   :show,
                   relation_parent_id,
                   "latest"
                 )
               )
               |> json_response(200)

      assert parents == []
      assert length(children) == 3
    end

    @tag :admin_authenticated
    @tag fixture: "test/fixtures/metadata"
    test "uploads structure, field and relation metadata when domain is specified", %{
      conn: conn,
      structures: structures,
      fields: fields,
      relations: relations
    } do
      domain = "domain_name"
      domain_id = :random.uniform(1_000_000)
      TaxonomyCache.put_domain(%{name: domain, id: domain_id, updated_at: DateTime.utc_now()})

      conn =
        post(conn, metadata_path(conn, :upload),
          data_structures: Map.put(structures, :filename, "structures"),
          data_fields: Map.put(fields, :filename, "fields"),
          data_structure_relations: Map.put(relations, :filename, "relations"),
          domain: domain
        )

      assert response(conn, 202) =~ ""

      # waits for loader to complete
      LoaderWorker.ping(20_000)

      conn = get(conn, data_structure_path(conn, :index))
      json_response = json_response(conn, 200)["data"]
      assert length(json_response) == 5 + 68

      assert Enum.all?(json_response, fn %{"domain_id" => id, "domain" => d} ->
               id == domain_id and domain == Map.get(d, "name")
             end)

      structure_id = get_id(json_response, "Calidad")

      assert %{"data" => data} =
               conn
               |> get(
                 data_structure_data_structure_version_path(conn, :show, structure_id, "latest")
               )
               |> json_response(200)

      assert length(data["parents"]) == 1
      assert length(data["siblings"]) == 4
      assert length(data["children"]) == 16
    end
  end

  describe "data lineage metadata upload" do
    @tag :admin_authenticated
    @tag fixture: "test/fixtures/lineage"
    test "uploads nodes and relations metadata", %{conn: conn, nodes: nodes, rels: rels} do
      refute File.exists?(Path.join([@import_dir, "nodes.csv"]))
      refute File.exists?(Path.join([@import_dir, "rels.csv"]))

      conn = post(conn, metadata_path(conn, :upload), nodes: nodes, rels: rels)
      assert response(conn, 202) =~ ""
      assert File.exists?(Path.join([@import_dir, "nodes.csv"]))
      assert File.exists?(Path.join([@import_dir, "rels.csv"]))
    end

    @tag :admin_authenticated
    @tag fixture: "test/fixtures/lineage"
    test "uploads nodes metadata", %{conn: conn, nodes: nodes} do
      refute File.exists?(Path.join([@import_dir, "nodes.csv"]))
      conn = post(conn, metadata_path(conn, :upload), nodes: nodes)
      assert response(conn, 202) =~ ""
      assert File.exists?(Path.join([@import_dir, "nodes.csv"]))
    end

    @tag :admin_authenticated
    @tag fixture: "test/fixtures/lineage"
    test "uploads relations metadata", %{conn: conn, rels: rels} do
      refute File.exists?(Path.join([@import_dir, "rels.csv"]))
      conn = post(conn, metadata_path(conn, :upload), rels: rels)
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
