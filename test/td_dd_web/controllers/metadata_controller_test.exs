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
  alias TdDd.Cache.StructureLoader
  alias TdDd.DataStructures
  alias TdDd.DataStructures.DataStructure
  alias TdDd.Lineage.GraphData
  alias TdDd.Loader.Worker
  alias TdDd.Search.MockIndexWorker

  setup_all do
    start_supervised(MockIndexWorker)
    start_supervised(StructureLoader)
    start_supervised(Worker)
    start_supervised(GraphData)
    start_supervised({Task.Supervisor, name: TdDd.TaskSupervisor})
    :ok
  end

  setup %{} = tags do
    insert(:system, name: "Power BI", external_id: "pbi")

    case tags[:fixture] do
      nil ->
        :ok

      fixture ->
        params =
          %{
            structures: "structures.csv",
            fields: "fields.csv",
            relations: "relations.csv"
          }
          |> Enum.map(fn {k, v} -> {k, Path.join([fixture, v])} end)
          |> Enum.filter(fn {_, v} -> File.exists?(v) end)
          |> Map.new(fn {k, v} -> {k, upload(v)} end)

        {:ok, params}
    end
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
      Worker.await(20_000)

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
      Worker.await(20_000)

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

      assert response(conn, :accepted) =~ ""

      # waits for loader to complete
      Worker.await(20_000)

      assert %{"data" => data} =
               conn
               |> get(data_structure_path(conn, :index))
               |> json_response(:ok)

      assert length(data) == 5 + 68

      structure_id = get_id(data, "Calidad")
      relation_parent_id = get_id(data, "Dashboard Gobierno y Calidad v1")

      assert %{"data" => data} =
               conn
               |> get(
                 data_structure_data_structure_version_path(conn, :show, structure_id, "latest")
               )
               |> json_response(:ok)

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
               |> json_response(:ok)

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
      domain_id = :random.uniform(1_000_000)
      domain_name = "domain_name#{domain_id}"
      domain_external_id = "domain_exid#{domain_id}"

      TaxonomyCache.put_domain(%{
        external_id: domain_external_id,
        name: domain_name,
        id: domain_id,
        updated_at: DateTime.utc_now()
      })

      conn =
        post(conn, metadata_path(conn, :upload),
          data_structures: Map.put(structures, :filename, "structures"),
          data_fields: Map.put(fields, :filename, "fields"),
          data_structure_relations: Map.put(relations, :filename, "relations"),
          domain: domain_external_id
        )

      assert response(conn, 202) =~ ""

      # waits for loader to complete
      Worker.await(20_000)

      conn = get(conn, data_structure_path(conn, :index))
      json_response = json_response(conn, 200)["data"]
      assert length(json_response) == 5 + 68

      assert Enum.all?(json_response, fn %{"domain_id" => id, "domain" => d} ->
               id == domain_id and domain_name == Map.get(d, "name") and
                 Map.get(d, "external_id") == domain_external_id
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

  describe "td-2520" do
    @tag :admin_authenticated
    test "synchronous load with parent_external_id and external_id", %{conn: conn} do
      insert(:system, external_id: "test1", name: "test1")

      assert conn
             |> post(metadata_path(conn, :upload),
               data_structures: upload("test/fixtures/td2520/structures1.csv")
             )
             |> response(:accepted)

      # wait for loader to complete
      Worker.await(20_000)

      assert %DataStructure{id: id} =
               DataStructures.get_data_structure_by_external_id("td-2520.root")

      assert conn
             |> post(metadata_path(conn, :upload),
               data_structures: upload("test/fixtures/td2520/structures2.csv"),
               data_structure_relations: upload("test/fixtures/td2520/relations2.csv"),
               parent_external_id: "td-2520.root",
               external_id: "td-2520.child1"
             )
             |> response(:ok)

      Worker.await(20_000)

      assert conn
             |> post(metadata_path(conn, :upload),
               data_structures: upload("test/fixtures/td2520/structures3.csv"),
               data_structure_relations: upload("test/fixtures/td2520/relations3.csv"),
               parent_external_id: "td-2520.root",
               external_id: "td-2520.child2"
             )
             |> response(:ok)

      conn =
        get(conn, Routes.data_structure_data_structure_version_path(conn, :show, id, "latest"))

      %{"children" => children} = json_response(conn, 200)["data"]
      assert Enum.count(children) == 2

      assert Enum.all?(["Child1", "Child2"], fn name ->
               Enum.any?(children, &(&1["name"] == name))
             end)
    end
  end

  defp upload(path) do
    %Plug.Upload{path: path, filename: Path.basename(path)}
  end

  defp get_id(json, name) do
    json
    |> Enum.find(&(&1["name"] == name))
    |> Map.get("id")
  end
end
