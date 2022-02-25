defmodule TdDq.Canada.ImplementationAbilities do
  @moduledoc false
  alias Ecto.Changeset
  alias TdDq.Auth.Claims
  alias TdDq.Implementations.Implementation
  alias TdDq.Permissions

  # Service accounts can do anything with Implementations
  def can?(%Claims{role: "service"}, _action, _target), do: true

  def can?(%Claims{} = claims, :list, Implementation) do
    Permissions.authorized?(claims, :view_quality_rule)
  end

  def can?(%Claims{} = claims, :manage, Implementation) do
    Permissions.authorized?(claims, :manage_quality_rule_implementations)
  end

  def can?(%Claims{} = claims, :show, %Implementation{domain_id: domain_id}) do
    Permissions.authorized?(claims, :view_quality_rule, domain_id)
  end

  def can?(%Claims{} = claims, :manage, %Implementation{domain_id: domain_id} = implementation) do
    permission = permission(implementation)
    Permissions.authorized?(claims, permission, domain_id)
  end

  def can?(%Claims{} = claims, action, %Changeset{} = changeset)
      when action in [:create, :delete, :update] do
    domain_id = domain_id(changeset)
    permission = permission(changeset)
    Permissions.authorized?(claims, permission, domain_id)
  end

  # Service accounts can execute rule implementations
  def can?(%Claims{role: "service"}, :execute, _), do: true

  def can?(%Claims{} = claims, :execute, %Implementation{domain_id: domain_id}) do
    Permissions.authorized?(claims, :execute_quality_rule_implementations, domain_id)
  end

  def can?(%Claims{} = claims, :execute, %{domain_ids: [domain_id | _]}) do
    Permissions.authorized?(claims, :execute_quality_rule_implementations, domain_id)
  end

  def can?(%Claims{} = claims, :manage_rule_results, %Implementation{domain_id: domain_id}) do
    Permissions.authorized?(claims, :manage_rule_results, domain_id)
  end

  def can?(_claims, _action, _resource), do: false

  defp domain_id(%{domain_id: domain_id}), do: domain_id
  defp domain_id(%Changeset{data: data}), do: domain_id(data)

  defp permission("raw"), do: :manage_raw_quality_rule_implementations
  defp permission("default"), do: :manage_quality_rule_implementations
  defp permission(%Implementation{implementation_type: type}), do: permission(type)

  defp permission(%Changeset{} = changeset) do
    changeset
    |> Changeset.fetch_field!(:implementation_type)
    |> permission()
  end
end
