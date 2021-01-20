defmodule MockPermissionResolver do
  @moduledoc """
  A mock permissions resolver for tests.
  """

  use Agent

  alias Jason
  alias TdCache.TaxonomyCache

  @initial_state %{sessions: Map.new(), acls: []}

  ## Public API

  def start_link(_init_arg) do
    Agent.start_link(
      fn -> @initial_state end,
      name: __MODULE__
    )
  end

  def register_token(resource) do
    if Process.whereis(__MODULE__) do
      %{"sub" => sub, "jti" => jti} = Map.take(resource, ["sub", "jti"])
      %{"id" => user_id} = Jason.decode!(sub)
      put_session(jti, user_id)
    end
  end

  def create_acl_entry(item) do
    Agent.update(__MODULE__, fn %{acls: acls} = state ->
      %{state | acls: [item | acls]}
    end)
  end

  def has_permission?(session_id, permission) do
    case TdCache.DomainCache.domains() do
      {:ok, domain_ids} -> has_resource_permission?(domain_ids, "domain", session_id, permission)
    end
  end

  def has_permission?(session_id, permission, "domain", domain_id) do
    domain_id
    |> TaxonomyCache.get_parent_ids()
    |> has_resource_permission?("domain", session_id, permission)
  end

  def has_permission?(session_id, permission, resource_type, resource_id) do
    has_resource_permission?([resource_id], resource_type, session_id, permission)
  end

  def get_acls_by_resource_type(session_id, resource_type) do
    Agent.get(__MODULE__, fn %{sessions: sessions, acls: acls} ->
      case Map.get(sessions, session_id) do
        nil ->
          []

        user_id ->
          acls
          |> Enum.filter(&(&1.principal_id == user_id && &1.resource_type == resource_type))
          |> Enum.map(&Map.take(&1, [:resource_type, :resource_id, :permissions, :role_name]))
      end
    end)
  end

  ## Private functions

  defp has_resource_permission?(resource_ids, resource_type, session_id, permission) do
    Agent.get(__MODULE__, fn %{acls: acls, sessions: sessions} ->
      case Map.get(sessions, session_id) do
        nil ->
          false

        user_id ->
          Enum.any?(
            acls,
            &(&1.principal_id == user_id &&
                &1.resource_type == resource_type &&
                &1.resource_id in resource_ids &&
                permission in &1.permissions)
          )
      end
    end)
  end

  defp put_session(session_id, user_id) do
    Agent.update(__MODULE__, fn %{sessions: sessions} = state ->
      %{state | sessions: Map.put(sessions, session_id, user_id)}
    end)
  end
end
