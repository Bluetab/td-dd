defmodule TdDd.Lineage.Units.Workers.DeleteUnitTest do
  use TdDd.DataCase

  alias TdDd.Lineage.Units.Unit
  alias TdDd.Lineage.Units.Workers.DeleteUnit

  describe "perform/1" do
    test "soft deletes a unit" do
      unit = insert(:unit)
      assert :ok = perform_job(DeleteUnit, %{"unit_id" => unit.id})
      assert Repo.get(Unit, unit.id).deleted_at
    end

    test "hard deletes a unit" do
      unit = insert(:unit)
      assert :ok = perform_job(DeleteUnit, %{"unit_id" => unit.id, "logical" => "false"})
      refute Repo.get(Unit, unit.id)
    end
  end
end
