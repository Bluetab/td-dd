defmodule TdDdWeb.ProfileExecutionGroupView do
  use TdDdWeb, :view

  alias TdDdWeb.ProfileExecutionView

  def render("index.json", %{profile_execution_groups: groups}) do
    %{data: render_many(groups, __MODULE__, "profile_execution_group.json")}
  end

  def render("show.json", %{profile_execution_group: group}) do
    %{data: render_one(group, __MODULE__, "profile_execution_group.json")}
  end

  def render("profile_execution_group.json", %{profile_execution_group: group}) do
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
    executions = render_many(executions, ProfileExecutionView, "profile_execution.json")
    Map.put(acc, :executions, executions)
  end

  defp put_embedding(_, acc), do: acc
end
