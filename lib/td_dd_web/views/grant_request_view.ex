defmodule TdDdWeb.GrantRequestView do
  use TdDdWeb, :view

  alias TdCache.TemplateCache
  alias TdDd.DataStructures.DataStructureVersion
  alias TdDd.Systems.System
  alias TdDdWeb.DataStructureVersionView
  alias TdDdWeb.DataStructureView
  alias TdDdWeb.GrantRequestApprovalView
  alias TdDdWeb.GrantRequestGroupView
  alias TdDdWeb.GrantRequestView
  alias TdDdWeb.GrantView
  alias TdDfLib.Content
  alias TdDfLib.Format

  @default_embeddings [:data_structure, :grant, :group, :approvals]

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
      :domain_ids,
      :request_type
    ])
    |> Map.put(:status, status)
    |> Map.put(:status_reason, status_reason)
    |> put_embeddings(grant_request, Map.get(assigns, :embed, @default_embeddings))
    |> add_cached_content()
    |> Content.legacy_content_support(:metadata)
  end

  def render("grant_request_search.json", %{grant_request: grant_request} = _assigns) do
    grant_request
    |> Map.take([
      :id,
      :user_id,
      :group_id,
      :created_by_id,
      :data_structure_id,
      :grant,
      :metadata,
      :inserted_at,
      :current_status,
      :request_type,
      :domain_ids,
      :modification_grant_id,
      :request_type
    ])
    |> add_structure_version(grant_request)
    |> add_system(grant_request)
    |> add_users(grant_request)
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
      {:data_structure, %Ecto.Association.NotLoaded{}}, acc ->
        acc

      {:data_structure, %{} = data_structure}, acc ->
        Map.put(
          acc,
          :data_structure,
          render_one(data_structure, DataStructureView, "embedded.json")
        )

      {:group, %{} = group}, acc ->
        Map.put(acc, :group, render_one(group, GrantRequestGroupView, "embedded.json"))

      {:grant, %{} = grant}, acc ->
        Map.put(acc, :grant, render_one(grant, GrantView, "grant.json"))

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

  defp add_system(resp, %{system: %System{} = system}) do
    system = Map.take(system, [:external_id, :id, :name])
    Map.put(resp, :system, system)
  end

  defp add_system(resp, _), do: resp

  defp add_structure_version(resp, %{
         data_structure_version: %DataStructureVersion{} = dsv
       }) do
    version =
      dsv
      |> DataStructureVersionView.add_ancestry()
      |> Map.take([:name, :ancestry])

    Map.put(resp, :data_structure_version, version)
  end

  defp add_structure_version(resp, %{
         data_structure_version: %{data_structure_id: _data_structure_id} = dsv
       }) do
    version =
      struct(DataStructureVersion, dsv)
      |> Map.take([
        :data_structure_id,
        :name,
        :description,
        :external_id,
        :metadata,
        :path,
        :note,
        :mutable_metadata
      ])
      |> Map.put(:domain, dsv.domain)

    Map.put(resp, :data_structure_version, version)
  end

  defp add_structure_version(resp, _), do: resp

  defp add_users(resp, %{user: %{} = user, created_by: %{} = created_by}) do
    resp
    |> Map.put(:user, get_user_data(user))
    |> Map.put(:created_by, get_user_data(created_by))
  end

  defp add_users(resp, _), do: resp

  defp get_user_data(user_data) do
    Map.take(user_data, [:email, :full_name, :user_name])
  end
end
