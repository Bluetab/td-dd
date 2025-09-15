defmodule TdDd.Search.StoreTest do
  use TdDd.DataStructureCase

  import ExUnit.CaptureLog
  import Mox

  alias TdCluster.TestHelpers.TdAiMock.Indices
  alias TdDd.DataStructures.DataStructureVersion
  alias TdDd.Grants.GrantRequest
  alias TdDd.Grants.GrantStructure
  alias TdDd.Search.EnricherImpl
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
      expect(TdDd.Search.EnricherImplMock, :async_enrich_versions, 1, fn chunked_ids_stream,
                                                                         relation_type_id,
                                                                         filters ->
        Stream.flat_map(
          chunked_ids_stream,
          &EnricherImpl.enrich_versions(&1, relation_type_id, filters)
        )
      end)

      [dsv | _] = Enum.map(1..11, fn _ -> insert(:data_structure_version) end)

      record_embedding = insert(:record_embedding, data_structure_version: dsv)

      assert versions =
               Store.transaction(fn ->
                 DataStructureVersion
                 |> Store.stream()
                 |> Enum.to_list()
               end)

      assert Enum.count(versions) == 11
      assert StructureEnricher.count() == 11
      assert %{record_embeddings: [embedding]} = Enum.find(versions, &(&1.id == dsv.id))
      assert record_embedding.collection == embedding.collection
      assert record_embedding.embedding == embedding.embedding
      assert record_embedding.dims == embedding.dims
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

  describe "Store.stream/2 of embeddings" do
    setup do
      start_supervised!(StructureEnricher)
      :ok
    end

    @tag sandbox: :shared
    test "streams data structure embeddings when data structure ids are provided" do
      Indices.list_indices(
        &Mox.expect/4,
        [enabled: true],
        {:ok, [%{collection_name: "default"}, %{collection_name: "other"}]}
      )

      embedding = insert(:record_embedding)

      other_embedding =
        insert(:record_embedding,
          data_structure_version: embedding.data_structure_version,
          collection: "other"
        )

      [dsv] =
        Store.transaction(fn ->
          DataStructureVersion
          |> Store.stream({:embeddings, [embedding.data_structure_version.data_structure_id]})
          |> Enum.to_list()
        end)

      for embedding <- [embedding, other_embedding] do
        result = Enum.find(dsv.record_embeddings, &(&1.id == embedding.id))
        assert result.collection == embedding.collection
        assert result.dims == embedding.dims
        assert result.embedding == embedding.embedding
      end

      assert dsv.embeddings == %{
               "vector_#{embedding.collection}" => embedding.embedding,
               "vector_#{other_embedding.collection}" => other_embedding.embedding
             }
    end
  end

  describe "Store.run/2 embeddings" do
    test "runs worker refreshing embeddings" do
      assert {:ok, %Oban.Job{}} = Store.run(DataStructureVersion, {:embeddings, :all})
    end
  end

  describe "Store.stream/2 of grants" do
    setup do
      start_supervised!(StructureEnricher)
      :ok
    end

    @tag sandbox: :shared
    test "streams chunked grants" do
      [_dsv1, dsv2, dsv3, dsv4] = create_hierarchy(["A", "B", "C", "D"])

      grant = insert(:grant, data_structure: dsv2.data_structure)

      grant_structures =
        Store.transaction(fn ->
          GrantStructure
          |> Store.stream([grant.id])
          |> Enum.to_list()
        end)

      assert [grant_structure_1, grant_structure_2, grant_structure_3] =
               Enum.sort_by(grant_structures, & &1.data_structure_version.name)

      assert grant_structure_1.grant.id == grant.id
      assert grant_structure_1.data_structure_version.id == dsv2.id
      assert grant_structure_2.grant.id == grant.id
      assert grant_structure_2.data_structure_version.id == dsv3.id
      assert grant_structure_3.grant.id == grant.id
      assert grant_structure_3.data_structure_version.id == dsv4.id
    end

    @tag sandbox: :shared
    test "streams chunked grant structures for delete" do
      [_dsv1, dsv2, dsv3, dsv4] = create_hierarchy(["A", "B", "C", "D"])

      grant = insert(:grant, data_structure: dsv2.data_structure)
      assert {:ok, _} = Repo.delete(grant)

      grant_structures =
        Store.transaction(fn ->
          GrantStructure
          |> Store.stream({:delete, [grant]})
          |> Enum.to_list()
        end)

      assert [grant_structure_1, grant_structure_2, grant_structure_3] =
               Enum.sort_by(grant_structures, & &1.data_structure_version.id)

      assert grant_structure_1.grant.id == grant.id
      assert grant_structure_1.data_structure_version.id == dsv2.id
      assert grant_structure_2.grant.id == grant.id
      assert grant_structure_2.data_structure_version.id == dsv3.id
      assert grant_structure_3.grant.id == grant.id
      assert grant_structure_3.data_structure_version.id == dsv4.id
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
