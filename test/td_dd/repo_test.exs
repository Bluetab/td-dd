defmodule TdDd.RepoTest do
  use TdDd.DataCase

  import ExUnit.CaptureLog

  alias TdDd.Repo

  describe "Repo.vacuum/1" do
    test "rejects unknown tables" do
      assert {:error, :invalid_name} = Repo.vacuum("foo")
    end

    test "vacuums a single table and logs messages" do
      assert capture_log(fn ->
               assert :ok = Repo.vacuum("systems")
             end) =~ "VACUUM cannot run inside a transaction block"
    end

    test "vacuums multiple tables passed as a list and logs messages" do
      assert capture_log(fn ->
               assert :ok = Repo.vacuum(["systems", "sources"])
             end) =~ "VACUUM cannot run inside a transaction block"
    end

    test "vacuums multiple tables passed as a string and logs messages" do
      assert capture_log(fn ->
               assert :ok = Repo.vacuum("systems sources")
             end) =~ "VACUUM cannot run inside a transaction block"
    end
  end
end
