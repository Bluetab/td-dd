defmodule TdDdWeb.GrantRequestView do
  use TdDdWeb, :view

  alias TdCache.TemplateCache
  alias TdDdWeb.DataStructureView
  alias TdDdWeb.GrantRequestApprovalView
  alias TdDdWeb.GrantRequestGroupView
  alias TdDdWeb.GrantRequestView
  alias TdDfLib.Format

  @default_embeddings [:data_structure, :group, :approvals]

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
    status_reason = Map.get(grant_request, :status_reason)

    grant_request
    |> Map.take([
      :id,
      :filters,
      :metadata,
      :inserted_at,
      :updated_at,
      :pending_roles,
      :all_pending_roles,
      :domain_ids
    ])
    |> Map.put(:status, status)
    |> Map.put(:status_reason, status_reason)
    |> put_embeddings(grant_request, Map.get(assigns, :embed, @default_embeddings))
    |> add_cached_content()
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

      {:approvals, approvals}, acc when is_list(approvals) ->
        Map.put(
          acc,
          :approvals,
          render_many(approvals, GrantRequestApprovalView, "grant_request_approval.json")
        )

      _, acc ->
        acc
    end)
  end

  defp add_cached_content(
         %{metadata: metadata, _embedded: %{group: %{type: grant_request_type}}} = grant_request
       ) do
    template = TemplateCache.get_by_name!(grant_request_type)
    metadata = Format.enrich_content_values(metadata, template, [:system, :hierarchy])
    Map.put(grant_request, :metadata, metadata)
  end

  defp add_cached_content(grant_request), do: grant_request
end
