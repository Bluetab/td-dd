defmodule TdDdWeb.ExecutionGroupView do
  use TdDdWeb, :view

  alias TdDdWeb.ExecutionView

  def render("index.json", %{execution_groups: groups}) do
    %{data: render_many(groups, __MODULE__, "group.json")}
  end

  def render("show.json", %{execution_group: group}) do
    %{data: render_one(group, __MODULE__, "group.json")}
  end

  def render("group.json", %{execution_group: group}) do
    json = Map.take(group, [:id, :inserted_at])

    case embeddings(group) do
      %{} = embeddings when embeddings != %{} -> Map.put(json, :_embedded, embeddings)
      _ -> json
    end
  end

  defp embeddings(%{} = group) do
    group
    |> Map.take([:executions])
    |> Enum.reduce(%{}, &put_embedding/2)
  end

  defp put_embedding({:executions, executions}, %{} = acc) when is_list(executions) do
    executions = render_many(executions, ExecutionView, "execution.json")
    Map.put(acc, :executions, executions)
  end

  defp put_embedding(_, acc), do: acc
end
