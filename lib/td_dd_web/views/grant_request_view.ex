defmodule TdDdWeb.GrantRequestView do
  use TdDdWeb, :view

  alias TdDdWeb.DataStructureView
  alias TdDdWeb.GrantRequestGroupView
  alias TdDdWeb.GrantRequestView

  @default_embeddings [:data_structure, :group]

  def render("index.json", %{grant_requests: grant_requests}) do
    %{data: render_many(grant_requests, GrantRequestView, "grant_request.json")}
  end

  def render("show.json", %{grant_request: grant_request}) do
    %{data: render_one(grant_request, GrantRequestView, "grant_request.json")}
  end

  def render("embedded.json", %{grant_request: grant_request, embed: embed}) do
    render("grant_request.json", %{grant_request: grant_request, embed: embed})
  end

  def render("grant_request.json", %{grant_request: grant_request} = assigns) do
    status = Map.get(grant_request, :current_status)

    grant_request
    |> Map.take([:id, :filters, :metadata, :inserted_at])
    |> Map.put(:status, status)
    |> put_embeddings(grant_request, Map.get(assigns, :embed, @default_embeddings))
  end

  defp put_embeddings(%{} = resp, grant_request, embed) do
    case embeddings(grant_request, embed) do
      map when map == %{} -> resp
      embeddings -> Map.put(resp, :_embedded, embeddings)
    end
  end

  defp embeddings(%{} = grant_request, embed) do
    grant_request
    |> Map.take(embed)
    |> Enum.reduce(%{}, fn
      {:data_structure, %{} = data_structure}, acc ->
        Map.put(
          acc,
          :data_structure,
          render_one(data_structure, DataStructureView, "embedded.json")
        )

      {:group, %{} = group}, acc ->
        Map.put(acc, :group, render_one(group, GrantRequestGroupView, "embedded.json"))

      _, acc ->
        acc
    end)
  end
end
