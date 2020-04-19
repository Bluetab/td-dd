defmodule TdDd.Loader.DeleteByGroupTest do
  use TdDd.DataCase

  alias TdDd.CSV.Reader
  alias TdDd.DataStructures
  alias TdDd.Loader

  @structure_import_schema Application.get_env(:td_dd, :metadata)[:structure_import_schema]
  @structure_import_required Application.get_env(:td_dd, :metadata)[:structure_import_required]
  @domain_map %{"Truedat" => 42}

  setup do
    %{id: system_id} = insert(:system, external_id: "system1", name: "SYS1")

    {:ok, structures1} =
      read_structures("test/fixtures/loader/delete_by_group/structures1.csv", system_id)

    {:ok, _} = Loader.load(structures1, [], [], audit())

    {:ok, structures} =
      read_structures("test/fixtures/loader/delete_by_group/structures2.csv", system_id)

    {:ok, structures: structures}
  end

  defp audit do
    ts = DateTime.truncate(DateTime.utc_now(), :second)
    %{last_change_by: 0, ts: ts}
  end

  defp read_structures(path, system_id) do
    path
    |> File.stream!()
    |> Reader.read_csv(
      domain_map: @domain_map,
      defaults: %{system_id: system_id, version: 0},
      schema: @structure_import_schema,
      required: @structure_import_required
    )
  end

  describe "TdDd.Loader" do
    test "sets the deleted_at of structures which are no longer present in the input CSV", %{
      structures: structures
    } do
      audit = audit()
      {:ok, data_structure_ids} = Loader.load(structures, [], [], audit)
      assert Enum.count(data_structure_ids) == 2

      dsvs = Enum.map(data_structure_ids, &DataStructures.get_latest_version/1)
      assert Enum.count(dsvs) == 2
      assert Enum.all?(dsvs, &(&1.group == "group1"))
      assert Enum.all?(dsvs, &(&1.deleted_at == audit.ts))
    end
  end
end
