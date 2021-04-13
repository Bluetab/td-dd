defmodule TdDdWeb.ProfileExecutionView do
  use TdDdWeb, :view

  def render("index.json", %{profile_executions: executions}) do
    %{data: render_many(executions, __MODULE__, "profile_execution.json")}
  end

  def render("show.json", %{profile_execution: execution}) do
    %{data: render_one(execution, __MODULE__, "profile_execution.json")}
  end

  def render("profile_execution.json", %{profile_execution: execution}) do
    json = Map.take(execution, [:id, :inserted_at])

    case embeddings(execution) do
      %{} = embeddings when embeddings != %{} -> Map.put(json, :_embedded, embeddings)
      _ -> json
    end
  end

  defp embeddings(%{} = execution) do
    execution
    |> Map.take([:data_structure, :profile, :latest])
    |> Enum.reduce(%{}, &put_embedding/2)
  end

  defp put_embedding({:data_structure, %{} = data_structure}, %{} = acc) do
    data_structure =
      data_structure
      |> with_structure_name()
      |> Map.take([:id, :external_id])

    Map.put(acc, :data_structure, data_structure)
  end

  defp put_embedding({:profile, %{} = profile}, %{} = acc) do
    profile =
      profile
      |> Map.get(:value)
      |> Enum.reject(fn {_, v} -> is_nil(v) end)
      |> Map.new(fn {k, v} -> {String.to_atom(k), v} end)
      |> Map.put(:inserted_at, Map.get(profile, :inserted_at))

    Map.put(acc, :profile, profile)
  end

  defp put_embedding({:latest, %{} = latest}, %{} = acc) do
    Map.put(acc, :latest, Map.take(latest, [:name]))
  end

  defp put_embedding(_, acc), do: acc

  defp with_structure_name(%{latest: %{name: name}} = data_structure),
    do: Map.put(data_structure, :name, name)

  defp with_structure_name(data_structure), do: data_structure
end
