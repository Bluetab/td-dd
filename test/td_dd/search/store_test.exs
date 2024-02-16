defmodule TdDd.Search.StoreTest do
  use TdDd.DataCase

  import ExUnit.CaptureLog

  alias TdDd.DataStructures.DataStructureVersion
  alias TdDd.Grants.GrantRequest
  alias TdDd.Search.Store
  alias TdDd.Search.StructureEnricher

  describe "Store.stream/1" do
    setup do
      Application.put_env(Store, :chunk_size, 10)
      start_supervised!(StructureEnricher)
      :ok
    end

    @tag sandbox: :shared
    test "streams enriched chunked data structure versions" do
      Enum.each(1..11, fn _ -> insert(:data_structure_version) end)

      assert Store.transaction(fn ->
               DataStructureVersion
               |> Store.stream()
               |> Enum.count()
             end) == 11

      assert StructureEnricher.count() == 11
    end

    @tag sandbox: :shared
    test "streams grant_request" do
      %{id: data_structure_id} = insert(:data_structure)
      insert(:data_structure_version, data_structure_id: data_structure_id)

      %{id: user_id, user_name: user_name, full_name: user_fullname} = CacheHelpers.insert_user()

      %{id: created_by_id, user_name: created_by_name, full_name: created_by_fullname} =
        CacheHelpers.insert_user()

      %{id: group_id} =
        insert(:grant_request_group, user_id: user_id, created_by_id: created_by_id)

      %{id: dsv_id} =
        insert(:data_structure_version, data_structure_id: data_structure_id, version: 2)

      %{id: grant_request_id, inserted_at: inserted_at} =
        insert(:grant_request, data_structure_id: data_structure_id, group_id: group_id)

      insert(:grant_request_status, grant_request_id: grant_request_id, status: "pending")

      %{status: status} =
        insert(:grant_request_status, grant_request_id: grant_request_id, status: "rejected")

      assert [
               %{
                 id: ^grant_request_id,
                 current_status: ^status,
                 data_structure_id: ^data_structure_id,
                 data_structure_version: %{id: ^dsv_id},
                 inserted_at: ^inserted_at,
                 group_id: ^group_id,
                 group: %{
                   created_by_id: ^created_by_id,
                   user_id: ^user_id
                 },
                 user: %{
                   id: ^user_id,
                   user_name: ^user_name,
                   full_name: ^user_fullname
                 },
                 created_by: %{
                   id: ^created_by_id,
                   user_name: ^created_by_name,
                   full_name: ^created_by_fullname
                 }
               }
             ] =
               Store.transaction(fn ->
                 GrantRequest
                 |> Store.stream()
                 |> Enum.to_list()
               end)
    end

    @tag sandbox: :shared
    test "streams grant_request for given ids" do
      %{id: user_id, user_name: user_name, full_name: user_fullname} = CacheHelpers.insert_user()

      %{id: data_structure_id} = insert(:data_structure)
      insert(:data_structure_version, data_structure_id: data_structure_id)

      %{id: dsv_id} =
        insert(:data_structure_version, data_structure_id: data_structure_id, version: 2)

      %{id: group_id} = insert(:grant_request_group, user_id: user_id)

      %{id: grant_request_id} =
        insert(:grant_request, data_structure_id: data_structure_id, group_id: group_id)

      insert(:grant_request, data_structure_id: data_structure_id)

      insert(:grant_request_status, grant_request_id: grant_request_id, status: "pending")

      %{status: status} =
        insert(:grant_request_status, grant_request_id: grant_request_id, status: "accepted")

      assert [
               %{
                 id: ^grant_request_id,
                 current_status: ^status,
                 data_structure_id: ^data_structure_id,
                 data_structure_version: %{id: ^dsv_id},
                 user: %{
                   id: ^user_id,
                   user_name: ^user_name,
                   full_name: ^user_fullname
                 }
               }
             ] =
               Store.transaction(fn ->
                 GrantRequest
                 |> Store.stream([grant_request_id])
                 |> Enum.to_list()
               end)
    end

    @tag sandbox: :shared
    test "streams grant_request with approval_by" do
      %{id: grant_request_id} = insert(:grant_request)

      approved_roles = ["rol1", "rol2"]

      for approval_role <- approved_roles do
        insert(:grant_request_approval, role: approval_role, grant_request_id: grant_request_id)
      end

      assert [
               %{
                 id: ^grant_request_id,
                 approved_by: ^approved_roles
               }
             ] =
               Store.transaction(fn ->
                 GrantRequest
                 |> Store.stream()
                 |> Enum.to_list()
               end)
    end
  end

  describe "Store.vacuum/0" do
    test "returns :ok and logs messages" do
      assert capture_log(fn ->
               assert :ok = Store.vacuum()
             end) =~ "VACUUM cannot run inside a transaction block"
    end
  end
end
