defmodule SearchHelpers do
  @moduledoc """
  Helper functions for mocking search responses.
  """
  import ExUnit.Assertions

  alias TdCx.Jobs.Job
  alias TdDd.DataStructures
  alias TdDd.DataStructures.DataStructureVersion
  alias TdDd.DataStructures.RelationTypes
  alias TdDd.Grants.Grant
  alias TdDd.Grants.GrantStructure
  alias TdDd.Repo
  alias TdDq.Implementations.Implementation

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
    total = total || %{"relation" => "eq", "value" => Enum.count(hits)}
    {:ok, %{"hits" => %{"hits" => hits, "total" => total}}}
  end

  def aggs_response(aggs \\ %{}, total \\ 0) do
    {:ok,
     %{
       "aggregations" => aggs,
       "hits" => %{"hits" => [], "total" => %{"relation" => "eq", "value" => total}}
     }}
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

    maybe_add_sort(%{"id" => id, "_source" => source}, doc)
  end

  defp maybe_add_sort(encoded, %DataStructureVersion{
         name: name,
         data_structure_id: data_structure_id
       }) do
    score = data_structure_id
    Map.put(encoded, "sort", [score, name, data_structure_id])
  end

  defp maybe_add_sort(encoded, _doc) do
    encoded
  end

  defp maybe_enrich(%DataStructureVersion{id: id}) do
    DataStructures.enriched_structure_versions(
      ids: [id],
      relation_type_id: RelationTypes.default_id!(),
      content: :searchable
    )
    |> hd()
  end

  defp maybe_enrich(%Grant{data_structure_version: data_structure_version} = grant) do
    %GrantStructure{grant: grant, data_structure_version: data_structure_version}
  end

  defp maybe_enrich(%Job{} = job) do
    Repo.preload(job, :events)
  end

  defp maybe_enrich(%Implementation{} = implementation) do
    Repo.preload(implementation, [:rule, :implementation_ref_struct])
  end

  defp maybe_enrich(other), do: other
end
