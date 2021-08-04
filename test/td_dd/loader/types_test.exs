defmodule TdDd.Loader.TypesTest do
  use TdDd.DataCase

  alias TdDd.Loader.Types
  alias TdDd.Repo

  describe "TdDd.Loader.Types.insert_missing_types/4" do
    test "inserts types which are not present in the database" do
      structure_records = [
        %{type: "t1"},
        %{type: "t2"},
        %{type: "t1"},
        %{type: "t2"}
      ]

      ts = DateTime.utc_now()
      assert {:ok, {2, types}} = Types.insert_missing_types(Repo, %{}, structure_records, ts)
      assert [%{name: "t1"}, %{name: "t2"}] = types
    end

    test "ignores types which are already present in the database" do
      %{name: existing_type_name} = insert(:data_structure_type)
      structure_records = [%{type: existing_type_name}]
      ts = DateTime.utc_now()
      assert {:ok, {0, []}} = Types.insert_missing_types(Repo, %{}, structure_records, ts)
    end
  end
end
