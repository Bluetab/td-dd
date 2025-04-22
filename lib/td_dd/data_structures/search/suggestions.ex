defmodule TdDd.DataStructures.Search.Suggestions do
  @num_candidates 100
  @k 10

  def knn(params) do
    params = default_params(params)
    _vector = vector_resource(params)
  end

  defp vector_resource(%{"resource_type" => "concepts", "resource_id" => id}) do
    # TODO
  end

  defp default_params(params) do
    params
    |> Map.put_new("num_candidates", @num_candidates)
    |> Map.put_new("k", @k)
  end
end
