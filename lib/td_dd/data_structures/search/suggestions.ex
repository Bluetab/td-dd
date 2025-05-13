defmodule TdDd.DataStructures.Search.Suggestions do
  @moduledoc """
  Suggestions search engine
  """
  alias TdCluster.Cluster.TdBg
  alias TdDd.DataStructures.Search
  alias Truedat.Auth.Claims

  @num_candidates 100
  @k 10
  @similarity 0.75

  def knn(%Claims{} = claims, permission, params) do
    {collection_name, vector} = generate_vector(params)

    params =
      params
      |> default_params()
      |> add_structure_ids()
      |> Map.put_new("query_vector", vector)
      |> Map.put_new("field", "embeddings.vector_#{collection_name}")

    Search.vector(claims, permission, params, similarity: :cosine)
  end

  defp default_params(params) do
    params
    |> Map.put_new("num_candidates", @num_candidates)
    |> Map.put_new("k", @k)
    |> Map.put_new("similarity", @similarity)
  end

  defp generate_vector(%{
         "resource" => %{"type" => "concepts", "id" => id, "version" => version} = params
       }) do
    %{id: id, version: version, embedding_params: %{links: links(params)}}
    |> TdBg.generate_vector(params["collection_name"])
    |> then(fn {:ok, version} -> version end)
  end

  defp links(params) do
    params
    |> Map.get("links", [])
    |> Enum.map(&link/1)
  end

  defp link(link) do
    link
    |> Map.take(["external_id", "type", "path", "description", "name"])
    |> Enum.into(%{}, fn
      {"external_id", external_id} -> {:external_id, external_id}
      {"name", name} -> {:name, name}
      {"type", type} -> {:type, type}
      {"path", path} -> {:path, path}
      {"description", description} -> {:description, description}
    end)
  end

  defp add_structure_ids(%{"resource" => %{"links" => links}} = params) do
    Map.put(params, "structure_ids", Enum.map(links, & &1["resource_id"]))
  end

  defp add_structure_ids(params), do: params
end
