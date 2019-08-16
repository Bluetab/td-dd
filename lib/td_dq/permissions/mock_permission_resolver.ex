defmodule TdDq.Permissions.MockPermissionResolver do
  @moduledoc false

  use Agent

  alias Jason, as: JSON

  @role_permissions %{
    "admin" => [
      :manage_confidential_business_concepts,
      :manage_quality_rule,
      :view_quality_rule
    ],
    "watch" => [
      :view_quality_rule
    ],
    "create" => [
      :view_quality_rule,
      :manage_quality_rule
    ],
    "confidential_watch" => [
      :view_quality_rule,
      :manage_confidential_business_concepts
    ],
    "execute_view" => [
      :view_quality_rule,
      :execute_quality_rule
    ],
    "execute" => [
      :execute_quality_rule
    ],
    "no_perms" => []
  }

  def start_link(_) do
    Agent.start_link(fn -> [] end, name: :MockPermissions)
    Agent.start_link(fn -> Map.new() end, name: :MockSessions)
    Agent.start_link(fn -> Map.new() end, name: :MockBusinessConcepts)
  end

  def has_permission?(session_id, permission, "business_concept", business_concept_id) do
    domain_ids = Agent.get(:MockBusinessConcepts, &Map.get(&1, business_concept_id, []))

    case domain_ids do
      [] ->
        false

      _ ->
        domain_ids
        |> Enum.any?(&has_resource_permission?(session_id, permission, "domain", &1))
    end
  end

  def has_permission?(_jti, _permission, _business_concept, _business_concept_id), do: true

  def has_permission?(_jti, _permission), do: true

  def has_resource_permission?(session_id, permission, resource_type, resource_id) do
    user_id = Agent.get(:MockSessions, &Map.get(&1, session_id))

    Agent.get(:MockPermissions, & &1)
    |> Enum.filter(
      &(&1.principal_id == user_id && &1.resource_type == resource_type &&
          &1.resource_id == resource_id)
    )
    |> Enum.any?(&can?(&1.role_name, permission))
  end

  defp can?("admin", _permission), do: true

  defp can?(role, permission) do
    case Map.get(@role_permissions, role) do
      nil -> false
      permissions -> Enum.member?(permissions, permission)
    end
  end

  def create_acl_entry(item) do
    Agent.update(:MockPermissions, &[item | &1])
  end

  def create_hierarchy(business_concept_id, domain_ids) do
    Agent.update(:MockBusinessConcepts, &Map.put(&1, business_concept_id, domain_ids))
  end

  def get_acl_entries do
    Agent.get(:MockPermissions, & &1)
  end

  def register_token(resource) do
    %{"sub" => sub, "jti" => jti} = resource |> Map.take(["sub", "jti"])
    %{"id" => user_id} = sub |> JSON.decode!()
    Agent.update(:MockSessions, &Map.put(&1, jti, user_id))
  end

  def get_acls_by_resource_type(session_id, resource_type) do
    user_id = Agent.get(:MockSessions, &Map.get(&1, session_id))

    Agent.get(:MockPermissions, & &1)
    |> Enum.filter(&(&1.principal_id == user_id && &1.resource_type == resource_type))
    |> Enum.map(fn %{role_name: role_name} = map ->
      Map.put(map, :permissions, Map.get(@role_permissions, role_name))
    end)
    |> Enum.map(&Map.take(&1, [:resource_type, :resource_id, :permissions, :role_name]))
  end
end
