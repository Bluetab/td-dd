defmodule TdDd.Loader.StructuresTest do
  use TdDd.DataCase

  import TdDd.TestOperators

  alias TdDd.DataStructures
  alias TdDd.DataStructures.DataStructure
  alias TdDd.Loader.Structures

  setup %{ids: ids} do
    %{id: system_id} = insert(:system)
    ts = DateTime.utc_now()

    entries =
      ids
      |> Enum.map(fn id ->
        %{
          external_id: "#{id}",
          domain_ids: [rem(id, 2)],
          inserted_at: ts,
          updated_at: ts,
          system_id: system_id
        }
      end)

    Repo.insert_all(DataStructure, entries)

    [ids: ids]
  end

  describe "update_domain_ids/2" do
    @tag ids: 1..10
    test "updates domain_id only if nil" do
      ts = DateTime.utc_now()
      records = [%{domain_id: 1, external_id: "1"}, %{domain_id: 42, external_id: "2"}]
      assert {:ok, {0, []}} = Structures.update_domain_ids(records, ts)
    end
  end

  describe "update_source_ids/2" do
    setup do
      start_supervised!(TdDd.Search.StructureEnricher)
      :ok
    end

    @tag ids: 1..10
    @tag sandbox: :shared
    test "updates source_id only if changed and source_id not nil" do
      %{id: id1} = insert(:source)
      %{id: id2} = insert(:source)

      ts = DateTime.utc_now()

      records = Enum.map(1..10, fn id -> %{external_id: "#{id}"} end)

      external_ids = Enum.map(records, & &1.external_id)
      structures = DataStructures.list_data_structures(external_id: external_ids)

      ids =
        structures
        |> Enum.map(& &1.id)
        |> Enum.sort()

      assert {0, []} = Structures.update_source_ids(records, nil, ts)
      assert {10, actual_ids} = Structures.update_source_ids(records, id1, ts)
      assert actual_ids ||| ids
      assert {0, []} = Structures.update_source_ids(records, id1, ts)
      assert {5, updated_ids} = Structures.update_source_ids(Enum.take(records, 5), id2, ts)
      assert updated_ids ||| Enum.take(ids, 5)
      assert {5, updated_ids} = Structures.update_source_ids(records, id2, ts)
      assert updated_ids ||| Enum.take(ids, -5)
      structures = DataStructures.list_data_structures(external_id: external_ids)
      assert Enum.all?(structures, &(&1.source_id == id2))
    end
  end

  describe "bulk_update_domain_ids/3" do
    @tag ids: 1..5_000
    test "bulk-updates domain_id only if nil, returns count and affected ids", %{ids: ids} do
      ts = DateTime.utc_now()
      domain_ids = [5, 7]

      assert {0, []} = Structures.bulk_update_domain_ids([], domain_ids, ts)

      %{id: id} =
        DataStructure
        |> Repo.get_by!(external_id: "42")
        |> Ecto.Changeset.change(domain_ids: [])
        |> Repo.update!()

      assert {1, [^id]} = Structures.bulk_update_domain_ids(["42"], domain_ids, ts)

      assert %{domain_ids: ^domain_ids} = Repo.get_by!(DataStructure, external_id: "42")
      string_ids = Enum.map(ids, &Integer.to_string/1)

      assert {0, []} = Structures.bulk_update_domain_ids(string_ids, nil, ts)
      assert {0, []} = Structures.bulk_update_domain_ids(string_ids, domain_ids, ts)
    end
  end
end
