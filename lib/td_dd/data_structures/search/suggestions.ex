defmodule TdDd.DataStructures.Search.Suggestions do
  @moduledoc """
  Suggestions search engine
  """
  alias TdCluster.Cluster.TdBg
  alias TdDd.DataStructures.Search
  alias Truedat.Auth.Claims

  @num_candidates 100
  @k 10

  def knn(%Claims{} = claims, permission, params) do
    {collection_name, vector} = generate_vector(params)

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

  defp generate_vector(
         %{"resource" => %{"type" => "concepts", "id" => id, "version" => version}} = params
       ) do
    %{id: id, version: version}
    |> TdBg.generate_vector(params["collection_name"])
    |> then(fn {:ok, version} -> version end)
  end
end
