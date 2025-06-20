defmodule CacheHelpers do
  @moduledoc """
  Support creation of domains in cache
  """

  import ExUnit.Callbacks, only: [on_exit: 1]
  import TdDd.Factory

  alias TdCache.AclCache
  alias TdCache.ConceptCache
  alias TdCache.HierarchyCache
  alias TdCache.I18nCache
  alias TdCache.ImplementationCache
  alias TdCache.LinkCache
  alias TdCache.Permissions
  alias TdCache.Redix
  alias TdCache.TagCache
  alias TdCache.TaxonomyCache
  alias TdCache.TemplateCache
  alias TdCache.UserCache
  alias TdDd.Search.StructureEnricher

  def insert_domain(params \\ %{}) do
    %{id: domain_id} = domain = build(:domain, params)
    on_exit(fn -> TaxonomyCache.delete_domain(domain_id, clean: true) end)
    TaxonomyCache.put_domain(domain)
    _maybe_error = StructureEnricher.refresh()
    domain
  end

  def insert_structure_type(params \\ []) do
    structure_type = insert(:data_structure_type, params)
    _maybe_error = StructureEnricher.refresh()
    structure_type
  end

  def insert_link(source_id, source_type, target_type, target_id, tags \\ [], origin \\ nil)

  def insert_link(source_id, source_type, target_type, nil, tags, origin) do
    target_id = System.unique_integer([:positive])
    insert_link(source_id, source_type, target_type, target_id, tags, origin)
  end

  def insert_link(source_id, source_type, target_type, target_id, tags, origin) do
    id = System.unique_integer([:positive])

    link =
      %{
        id: id,
        source_type: source_type,
        source_id: source_id,
        target_type: target_type,
        target_id: target_id,
        tags: tags,
        updated_at: DateTime.utc_now(),
        origin: origin
      }

    LinkCache.put(link, publish: false)

    on_exit(fn -> LinkCache.delete(id, publish: false) end)
    _maybe_error = StructureEnricher.refresh()
    link
  end

  def insert_tag(type, target_type, expandable) do
    id = System.unique_integer([:positive])

    tag = %{
      id: id,
      value: %{"type" => type, "target_type" => target_type, "expandable" => expandable},
      updated_at: DateTime.utc_now()
    }

    TagCache.put(tag)

    on_exit(fn -> TagCache.delete(id) end)
    tag
  end

  def insert_template(params \\ %{}) do
    %{id: template_id} = template = build(:template, params)
    on_exit(fn -> delete_template(template_id) end)
    {:ok, _} = TemplateCache.put(template, publish: false)
    _maybe_error = StructureEnricher.refresh()
    template
  end

  def delete_template(template_id) do
    TemplateCache.delete(template_id)
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

  def insert_acl(resource_id, role, user_ids, resource_type \\ "domain") do
    on_exit(fn ->
      AclCache.delete_acl_roles(resource_type, resource_id)
      AclCache.delete_acl_role_users(resource_type, resource_id, role)
    end)

    AclCache.set_acl_roles(resource_type, resource_id, [role])
    AclCache.set_acl_role_users(resource_type, resource_id, role, user_ids)
    :ok
  end

  def insert_hierarchy(params) do
    %{id: hierarchy_id} = hierarchy = build(:hierarchy, params)

    {:ok, _} = HierarchyCache.put(hierarchy, publish: false)
    on_exit(fn -> HierarchyCache.delete(hierarchy_id) end)
    hierarchy
  end

  def put_permission_by_role(entries) when is_list(entries) do
    entries =
      entries
      |> Enum.map(&Map.merge(%{resource_type: "domain"}, &1))
      |> Enum.flat_map(&expand_resource_ids/1)

    put_permission_roles_fn = fn roles_by_permission ->
      commands =
        Enum.map(roles_by_permission, fn {permission, role_names} ->
          ["SREM", "permission:" <> permission <> ":roles" | role_names]
        end)

      on_exit(fn ->
        Redix.transaction_pipeline!(commands)
      end)

      Permissions.put_permission_roles(roles_by_permission)
    end

    entries
    |> Enum.group_by(&Map.get(&1, :permission))
    |> Enum.map(fn {permission, permission_entries} ->
      {permission,
       Enum.reduce(permission_entries, [], fn entry, role_names ->
         [Map.get(entry, :role) | role_names]
       end)
       |> Enum.uniq()}
    end)
    |> Map.new()
    |> put_permission_roles_fn.()

    for {user_id, user_entries} <- Enum.group_by(entries, & &1.user_id) do
      user_entries
      |> Enum.group_by(& &1.resource_type)
      |> Enum.each(fn {resource_type, resource_ids} ->
        resource_ids_by_role =
          resource_ids
          |> Enum.group_by(&Map.get(&1, :role), & &1.resource_id)
          |> Map.new(fn {role, grouped_resource_ids} ->
            {role, List.flatten(grouped_resource_ids)}
          end)

        on_exit(fn ->
          Redix.command!(["DEL", "user:#{user_id}:roles:#{resource_type}"])
        end)

        UserCache.refresh_resource_roles(user_id, resource_type, resource_ids_by_role)
      end)
    end

    for {resource_type, resource_entries_by_type} <- Enum.group_by(entries, & &1.resource_type) do
      for {resource_id, resource_entries} <-
            Enum.group_by(resource_entries_by_type, & &1.resource_id) do
        for {role, user_ids} <- Enum.group_by(resource_entries, &Map.get(&1, :role), & &1.user_id) do
          insert_acl(resource_id, role, user_ids, resource_type)
        end
      end
    end
  end

  def put_grant_request_approvers(entries) when is_list(entries) do
    Enum.map(entries, fn entry ->
      entry
      |> Map.put(:permission, Map.get(entry, :permission, "approve_grant_request"))
      |> Map.put(:role, Map.get(entry, :role, "approver"))
    end)
    |> put_permission_by_role()
  end

  defp expand_resource_ids(%{resource_ids: resource_ids} = entry) do
    Enum.map(resource_ids, &Map.put(entry, :resource_id, &1))
  end

  defp expand_resource_ids(entry), do: [entry]

  def put_permission_on_role(permission, role_name) do
    put_permissions_on_roles(%{permission => [role_name]})
  end

  def put_permissions_on_roles(permissions) do
    TdCache.Permissions.put_permission_roles(permissions)
  end

  def put_session_permissions(%{} = claims, resource_id, permissions, resource_type \\ "domain") do
    resource_ids_by_type_and_permission = %{
      resource_type => Map.new(permissions, &{to_string(&1), [resource_id]})
    }

    put_session_permissions(claims, resource_ids_by_type_and_permission)
  end

  def put_session_permissions(%{jti: session_id, exp: exp}, %{} = resource_ids) do
    resource_ids
    |> with_default_resource_type()
    |> Enum.map(fn {resource_type, resource_ids_by_permission} ->
      put_sessions_permissions(session_id, exp, resource_ids_by_permission, resource_type)
    end)
  end

  defp put_sessions_permissions(session_id, exp, resource_ids_by_permission, resource_type) do
    on_exit(fn -> Redix.del!("session:#{session_id}:#{resource_type}:permissions") end)

    Permissions.cache_session_permissions!(session_id, exp, %{
      resource_type => resource_ids_by_permission
    })
  end

  def put_default_permissions(permissions) do
    on_exit(fn -> TdCache.Permissions.put_default_permissions([]) end)
    TdCache.Permissions.put_default_permissions(permissions)
  end

  def put_implementation(%{implementation_ref: implementation_ref} = implementation) do
    on_exit(fn -> ImplementationCache.delete(implementation_ref) end)
    ImplementationCache.put(implementation, publish: false)
  end

  def get_implementation(implementation_id) do
    ImplementationCache.get(implementation_id)
  end

  def get_link(link_id) do
    LinkCache.get(link_id)
  end

  def put_i18n_messages(lang, messages) when is_list(messages) do
    Enum.each(messages, &I18nCache.put(lang, &1))
    on_exit(fn -> I18nCache.delete(lang) end)
  end

  def put_i18n_message(lang, message), do: put_i18n_messages(lang, [message])

  defp with_default_resource_type(resource_ids) do
    has_resource_type =
      Enum.all?(resource_ids, fn
        {_k, %{}} -> true
        {_k, _} -> false
      end)

    if has_resource_type do
      resource_ids
    else
      %{"domain" => resource_ids}
    end
  end
end
