defmodule SearchHelpers do
  @moduledoc """
  Helper functions for mocking search responses.
  """
  import ExUnit.Assertions

  def expect_bulk_index(url, n \\ 1) do
    ElasticsearchMock
    |> Mox.expect(:request, n, fn _, :post, expected_url, _, [] ->
      assert url == expected_url
      bulk_index_response()
    end)
  end

  def bulk_index_response do
    {:ok, %{"errors" => false, "items" => [], "took" => 0}}
  end

  def hits_response(hits, total \\ nil) when is_list(hits) do
    hits = Enum.map(hits, &encode/1)
    total = total || Enum.count(hits)
    {:ok, %{"hits" => %{"hits" => hits, "total" => total}}}
  end

  def aggs_response(aggs \\ %{}) do
    {:ok, %{"aggregations" => aggs}}
  end

  def scroll_response(hits, total \\ nil) do
    {:ok, resp} = hits_response(hits, total)
    {:ok, Map.put(resp, "_scroll_id", "some_scroll_id")}
  end

  defp encode(doc) do
    doc = maybe_enrich(doc)

    id = Elasticsearch.Document.id(doc)

    source =
      doc
      |> Elasticsearch.Document.encode()
      |> Jason.encode!()
      |> Jason.decode!()

    %{"id" => id, "_source" => source}
  end

  defp maybe_enrich(%TdDd.DataStructures.DataStructureVersion{id: id}) do
    TdDd.DataStructures.enriched_structure_versions(
      ids: [id],
      relation_type_id: TdDd.DataStructures.RelationTypes.default_id!(),
      content: :searchable
    )
    |> hd()
  end

  defp maybe_enrich(%TdDd.Grants.Grant{data_structure_version: data_structure_version} = grant) do
    %TdDd.Grants.GrantStructure{grant: grant, data_structure_version: data_structure_version}
  end

  defp maybe_enrich(%TdCx.Jobs.Job{} = job) do
    TdDd.Repo.preload(job, :events)
  end

  defp maybe_enrich(%TdDq.Implementations.Implementation{} = implementation) do
    TdDd.Repo.preload(implementation, :rule)
  end

  defp maybe_enrich(other), do: other
end
