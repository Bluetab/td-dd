defmodule CacheHelpers do
  @moduledoc """
  Support creation of domains in cache
  """

  import ExUnit.Callbacks, only: [on_exit: 1]
  import TdDd.Factory

  alias TdCache.AclCache
  alias TdCache.ConceptCache
  alias TdCache.LinkCache
  alias TdCache.Permissions
  alias TdCache.Redix
  alias TdCache.TaxonomyCache
  alias TdCache.TemplateCache
  alias TdCache.UserCache
  alias TdDd.Search.StructureEnricher

  def insert_domain(params \\ %{}) do
    %{id: domain_id} = domain = build(:domain, params)
    on_exit(fn -> TaxonomyCache.delete_domain(domain_id, clean: true) end)
    TaxonomyCache.put_domain(domain, publish: false)
    _maybe_error = StructureEnricher.refresh()
    domain
  end

  def insert_structure_type(params \\ []) do
    structure_type = insert(:data_structure_type, params)
    _maybe_error = StructureEnricher.refresh()
    structure_type
  end

  def insert_link(data_structure_id, target_id \\ nil) do
    id = System.unique_integer([:positive])
    target_id = if is_nil(target_id), do: System.unique_integer([:positive]), else: target_id

    LinkCache.put(
      %{
        id: id,
        source_type: "data_structure",
        source_id: data_structure_id,
        target_type: "business_concept",
        target_id: target_id,
        updated_at: DateTime.utc_now()
      },
      publish: false
    )

    on_exit(fn -> LinkCache.delete(id, publish: false) end)
    _maybe_error = StructureEnricher.refresh()
    :ok
  end

  def insert_template(params \\ %{}) do
    %{id: template_id} = template = build(:template, params)
    {:ok, _} = TemplateCache.put(template, publish: false)
    on_exit(fn -> TemplateCache.delete(template_id) end)
    _maybe_error = StructureEnricher.refresh()
    template
  end

  def insert_concept(params \\ %{}) do
    %{id: id} = concept = build(:concept, params)
    on_exit(fn -> ConceptCache.delete(id) end)
    {:ok, _} = ConceptCache.put(concept)
    concept
  end

  def insert_user(params \\ %{}) do
    %{id: id} = user = build(:user, params)
    on_exit(fn -> UserCache.delete(id) end)
    {:ok, _} = UserCache.put(user)
    user
  end

  def insert_acl(domain_id, role, user_ids) do
    on_exit(fn ->
      AclCache.delete_acl_roles("domain", domain_id)
      AclCache.delete_acl_role_users("domain", domain_id, role)
    end)

    AclCache.set_acl_role_users("domain", domain_id, role, user_ids)
    :ok
  end

  def put_grant_request_approvers(entries) when is_list(entries) do
    entries = Enum.flat_map(entries, &expand_domain_ids/1)

    role_fn = fn map -> Map.get(map, :role, "approver") end
    role_names = entries |> MapSet.new(&role_fn.(&1)) |> MapSet.to_list()

    on_exit(fn ->
      Redix.command!(["SREM", "permission:approve_grant_request:roles" | role_names])
    end)

    Permissions.put_permission_roles(%{"approve_grant_request" => role_names})

    for {user_id, user_entries} <- Enum.group_by(entries, & &1.user_id) do
      domain_ids_by_role =
        user_entries
        |> Enum.group_by(&role_fn.(&1), & &1.domain_id)
        |> Map.new(fn {k, v} -> {k, List.flatten(v)} end)

      UserCache.put_roles(user_id, domain_ids_by_role)
    end

    for {domain_id, domain_entries} <- Enum.group_by(entries, & &1.domain_id) do
      for {role, user_ids} <- Enum.group_by(domain_entries, &role_fn.(&1), & &1.user_id) do
        insert_acl(domain_id, role, user_ids)
      end
    end
  end

  defp expand_domain_ids(%{domain_ids: domain_ids} = entry) do
    Enum.map(domain_ids, &Map.put(entry, :domain_id, &1))
  end

  defp expand_domain_ids(entry), do: [entry]

  def put_session_permissions(%{} = claims, domain_id, permissions) do
    domain_ids_by_permission = Map.new(permissions, &{to_string(&1), [domain_id]})
    put_session_permissions(claims, domain_ids_by_permission)
  end

  def put_session_permissions(%{jti: session_id, exp: exp}, %{} = domain_ids_by_permission) do
    put_sessions_permissions(session_id, exp, domain_ids_by_permission)
  end

  def put_sessions_permissions(session_id, exp, domain_ids_by_permission) do
    on_exit(fn -> Redix.del!("session:#{session_id}:permissions") end)
    Permissions.cache_session_permissions!(session_id, exp, domain_ids_by_permission)
  end
end
