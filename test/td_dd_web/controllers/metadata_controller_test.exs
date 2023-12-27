defmodule TdDdWeb.MetadataControllerTest do
  use TdDdWeb.ConnCase
  use PhoenixSwagger.SchemaTest, "priv/static/swagger.json"

  import Ecto.Query
  import ExUnit.CaptureLog
  import Mox

  alias TdCore.Search.MockIndexWorker
  alias TdDd.DataStructures
  alias TdDd.DataStructures.DataStructure
  alias TdDd.DataStructures.DataStructureRelation
  alias TdDd.DataStructures.DataStructureVersion
  alias TdDd.Loader.Worker
  alias TdDd.Repo

  @moduletag sandbox: :shared
  @protected DataStructures.protected()

  setup_all do
    start_supervised!(TdCore.Search.Cluster)
    start_supervised!(TdCore.Search.IndexWorker)

    start_supervised!(Worker)
    start_supervised!(TdDd.Lineage.GraphData)
    start_supervised!({Task.Supervisor, name: TdDd.TaskSupervisor})
    :ok
  end

  setup :set_mox_from_context
  setup :verify_on_exit!

  setup tags do
    start_supervised!(TdDd.Search.StructureEnricher)
    insert(:system, name: "Power BI", external_id: "pbi")

    case tags[:fixture] do
      nil ->
        :ok

      fixture ->
        process_fixture(fixture)
    end
  end

  describe "upload" do
    setup :create_source

    @tag authentication: [role: "service"]
    @tag fixture: "test/fixtures/metadata"
    test "uploads structure, field and relation metadata", %{
      conn: conn,
      structures: structures,
      fields: fields,
      relations: relations
    } do
      assert conn
             |> post(Routes.metadata_path(conn, :upload),
               data_structures: structures,
               data_fields: fields,
               data_structure_relations: relations
             )
             |> response(:accepted)

      # waits for loader to complete
      Worker.await(20_000)

      count =
        DataStructure
        |> select([ds], count(ds.id))
        |> Repo.one!()

      assert count == 5 + 68

      count =
        DataStructureRelation
        |> select([dsr], count(dsr.id))
        |> Repo.one!()

      assert count == 5 + 68 - 1
    end

    @tag authentication: [role: "service"]
    @tag fixture: "test/fixtures/metadata/field_external_id"
    test "maintains field_external_id if specified", %{
      conn: conn,
      structures: structures,
      fields: fields
    } do
      assert conn
             |> post(Routes.metadata_path(conn, :upload),
               data_structures: structures,
               data_fields: fields
             )
             |> response(:accepted)

      # waits for loader to complete
      Worker.await(20_000)

      external_ids =
        DataStructure
        |> select([ds], ds.external_id)
        |> Repo.all()

      assert_lists_equal(external_ids, [
        "parent_external_id",
        "parent_external_id/Field1",
        "field_with_external_id"
      ])
    end

    @tag authentication: [role: "service"]
    @tag fixture: "test/fixtures/metadata/field_external_id"
    test "delete elastic search index when structure is not loaded", %{
      conn: conn,
      structures: structures,
      fields: fields
    } do
      MockIndexWorker.clear()

      assert conn
             |> post(Routes.metadata_path(conn, :upload),
               data_structures: structures,
               data_fields: fields
             )
             |> response(:accepted)

      # waits for loader to complete
      Worker.await(20_000)

      %{structures: new_structures, fields: new_fields} =
        process_fixture("test/fixtures/metadata/field_external_id_deleted")

      assert conn
             |> post(Routes.metadata_path(conn, :upload),
               data_structures: new_structures,
               data_fields: new_fields
             )
             |> response(:accepted)

      # waits for loader to complete
      Worker.await(20_000)

      assert [
               {:reindex, :structures, _},
               {:reindex, :structures, _},
               {:delete, :structures, [_, _, _]}
             ] = MockIndexWorker.calls()
    end

    @tag authentication: [role: "service"]
    @tag fixture: "test/fixtures/metadata/relation_type"
    test "uploads structure, field and relation with relation_type_name metadata", %{
      conn: conn,
      structures: structures,
      fields: fields,
      relations: relations
    } do
      insert(:relation_type, name: "relation_type_1")

      assert "" =
               conn
               |> post(Routes.metadata_path(conn, :upload),
                 data_structures: structures,
                 data_fields: fields,
                 data_structure_relations: relations
               )
               |> response(:accepted)

      # waits for loader to complete
      Worker.await(20_000)

      %{id: id} = Repo.get_by!(DataStructureVersion, name: "Dashboard Gobierno y Calidad v1")

      frequencies =
        DataStructureRelation
        |> where(parent_id: ^id)
        |> preload(:relation_type)
        |> Repo.all()
        |> Enum.frequencies_by(& &1.relation_type.name)

      assert frequencies == %{"default" => 3, "relation_type_1" => 1}
    end

    @tag authentication: [role: "service"]
    @tag fixture: "test/fixtures/metadata"
    test "uploads structure, field and relation metadata when domain is specified", %{
      conn: conn,
      structures: structures,
      fields: fields,
      relations: relations
    } do
      %{id: domain_id, external_id: domain_external_id} = CacheHelpers.insert_domain()

      assert "" =
               conn
               |> post(Routes.metadata_path(conn, :upload),
                 data_structures: structures,
                 data_fields: fields,
                 data_structure_relations: relations,
                 domain: domain_external_id
               )
               |> response(:accepted)

      # waits for loader to complete
      Worker.await(20_000)

      frequencies =
        DataStructure
        |> Repo.all()
        |> Enum.frequencies_by(& &1.domain_ids)

      assert frequencies == %{[domain_id] => 5 + 68}
    end

    @tag authentication: [role: "service"]
    @tag fixture: "test/fixtures/metadata"
    test "uploads structure, field and relation metadata when source external id is specified", %{
      conn: conn,
      structures: structures,
      fields: fields,
      relations: relations,
      source: %{external_id: source_external_id}
    } do
      assert "" =
               conn
               |> post(Routes.metadata_path(conn, :upload),
                 data_structures: structures,
                 data_fields: fields,
                 data_structure_relations: relations,
                 source: source_external_id
               )
               |> response(:accepted)

      # waits for loader to complete
      Worker.await(20_000)

      frequencies =
        DataStructure
        |> preload(:source)
        |> Repo.all()
        |> Enum.frequencies_by(& &1.source.external_id)

      assert frequencies == %{source_external_id => 5 + 68}
    end
  end

  @tag authentication: [role: "service"]
  test "protected metadata", %{conn: conn} do
    insert(:system, external_id: "test1", name: "test1")

    assert conn
           |> post(Routes.metadata_path(conn, :upload),
             data_structures: upload("test/fixtures/td5082/structures_protected_metadata.csv")
           )
           |> response(:accepted)

    # wait for loader to complete
    Worker.await(20_000)

    assert %DataStructure{
             id: id,
             current_metadata: %{
               fields: %{
                 @protected => %{
                   "mmp1" => "mmp1_value",
                   "mmp2" => "mmp2_value"
                 }
               }
             }
           } =
             DataStructures.get_data_structure_by_external_id("structure_mp")
             |> Repo.preload(:current_metadata)

    assert %DataStructureVersion{
             mutable_metadata: %{
               @protected => %{
                 "mmp1" => "mmp1_value",
                 "mmp2" => "mmp2_value"
               }
             },
             metadata: %{
               @protected => %{
                 "mp1" => "mp1_value",
                 "mp2" => "mp2_value"
               }
             }
           } = DataStructures.get_latest_version(id, [:with_protected_metadata])
  end

  describe "td-2520" do
    @tag authentication: [role: "service"]
    test "synchronous load with parent_external_id and external_id", %{conn: conn} do
      insert(:system, external_id: "test1", name: "test1")

      assert conn
             |> post(Routes.metadata_path(conn, :upload),
               data_structures: upload("test/fixtures/td2520/structures1.csv")
             )
             |> response(:accepted)

      # wait for loader to complete
      Worker.await(20_000)

      assert %DataStructure{id: id} =
               DataStructures.get_data_structure_by_external_id("td-2520.root")

      assert conn
             |> post(Routes.metadata_path(conn, :upload),
               data_structures: upload("test/fixtures/td2520/structures2.csv"),
               data_structure_relations: upload("test/fixtures/td2520/relations2.csv"),
               parent_external_id: "td-2520.root",
               external_id: "td-2520.child1"
             )
             |> response(:ok)

      Worker.await(20_000)

      assert conn
             |> post(Routes.metadata_path(conn, :upload),
               data_structures: upload("test/fixtures/td2520/structures3.csv"),
               data_structure_relations: upload("test/fixtures/td2520/relations3.csv"),
               parent_external_id: "td-2520.root",
               external_id: "td-2520.child2"
             )
             |> response(:ok)

      assert %{"data" => data} =
               conn
               |> get(
                 Routes.data_structure_data_structure_version_path(conn, :show, id, "latest")
               )
               |> json_response(:ok)

      assert %{"children" => children} = data
      assert_lists_equal(children, ["Child1", "Child2"], &(&1["name"] == &2))
    end

    @tag authentication: [role: "service"]
    test "validate_graph", %{conn: conn} do
      insert(:system, external_id: "test1", name: "test1")

      assert conn
             |> post(Routes.metadata_path(conn, :upload),
               data_structures: upload("test/fixtures/td2520/structures2.csv"),
               data_structure_relations: upload("test/fixtures/td2520/relations2.csv")
             )
             |> response(:accepted)

      # wait for loader to complete
      Worker.await(20_000)

      assert capture_log(fn ->
               assert %{"message" => "vertex exists: td-2520.fieldchild1"} =
                        conn
                        |> post(Routes.metadata_path(conn, :upload),
                          data_structures: upload("test/fixtures/td2520/structures2.csv"),
                          data_structure_relations: upload("test/fixtures/td2520/relations2.csv"),
                          parent_external_id: "td-2520.fieldchild1",
                          external_id: "td-2520.child1"
                        )
                        |> json_response(:unprocessable_entity)
             end) =~ "vertex exists: td-2520.fieldchild1"
    end
  end

  defp create_source(_) do
    [source: insert(:source)]
  end

  defp process_fixture(fixture) do
    %{
      structures: "structures.csv",
      fields: "fields.csv",
      relations: "relations.csv"
    }
    |> Enum.map(fn {k, v} -> {k, Path.join([fixture, v])} end)
    |> Enum.filter(fn {_, v} -> File.exists?(v) end)
    |> Map.new(fn {k, v} -> {k, upload(v)} end)
  end
end
