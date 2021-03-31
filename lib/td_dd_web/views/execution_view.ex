defmodule TdDdWeb.ExecutionView do
  use TdDdWeb, :view

  def render("index.json", %{executions: executions}) do
    %{data: render_many(executions, __MODULE__, "execution.json")}
  end

  def render("show.json", %{execution: execution}) do
    %{data: render_one(execution, __MODULE__, "execution.json")}
  end

  def render("execution.json", %{execution: execution}) do
    json = Map.take(execution, [:id, :inserted_at])

    case embeddings(execution) do
      %{} = embeddings when embeddings != %{} -> Map.put(json, :_embedded, embeddings)
      _ -> json
    end
  end

  defp embeddings(%{} = execution) do
    execution
    |> Map.take([:data_structure, :profile])
    |> Enum.reduce(%{}, &put_embedding/2)
  end

  defp put_embedding({:data_structure, %{} = data_structure}, %{} = acc) do
    data_structure = Map.take(data_structure, [:id, :external_id])
    Map.put(acc, :data_structure, data_structure)
  end

  defp put_embedding({:profile, %{} = profile}, %{} = acc) do
    profile =
      profile
      |> Map.get(:value)
      |> Enum.reject(fn {_, v} -> is_nil(v) end)
      |> Map.new(fn {k, v} -> {String.to_atom(k), v} end)

    Map.put(acc, :profile, profile)
  end

  defp put_embedding(_, acc), do: acc
end
