defmodule TdDd.DataStructures.Search.Suggestions do
  @moduledoc """
  Suggestions search
  """
  alias TdCache.TemplateCache
  alias TdCluster.Cluster.TdAi.Embeddings
  alias TdCluster.Cluster.TdBg
  alias TdDd.DataStructures.Search
  alias TdDfLib.Format
  alias Truedat.Auth.Claims

  @num_candidates 100
  @k 10

  def knn(%Claims{} = claims, permission, params) do
    {collection_name, vector} =
      params
      |> vector_resource()
      |> generate_vector(params)

    params =
      params
      |> default_params()
      |> Map.put_new("query_vector", vector)
      |> Map.put_new("field", "embeddings.vector_#{collection_name}")

    Search.vector(claims, permission, params)
  end

  defp default_params(params) do
    params
    |> Map.put_new("num_candidates", @num_candidates)
    |> Map.put_new("k", @k)
  end

  defp vector_resource(%{"resource" => %{"type" => "concepts", "id" => id, "version" => version}}) do
    id
    |> TdBg.get_business_concept_version(version)
    |> then(fn {:ok, version} -> version end)
  end

  defp generate_vector(
         %{name: name, content: content, business_concept: business_concept},
         params
       ) do
    template = TemplateCache.get_by_name!(business_concept.type) || %{content: []}

    content =
      Format.search_values(content || %{}, template, domain_id: business_concept.domain.id)

    "#{name} #{content["df_description"]["value"]}"
    |> Embeddings.generate_vector(params["collection_name"])
    |> then(fn {:ok, vector} -> vector end)
  end
end
