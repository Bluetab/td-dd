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

  def can?(%Claims{} = claims, :show, %Implementation{} = implementation) do
    domain_id = domain_id(implementation)
    Permissions.authorized?(claims, :view_quality_rule, domain_id)
  end

  def can?(%Claims{} = claims, :manage, %Implementation{} = implementation) do
    domain_id = domain_id(implementation)
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

  def can?(%Claims{} = claims, :execute, %Implementation{rule: %{domain_id: domain_id}}) do
    Permissions.authorized?(claims, :execute_quality_rule_implementations, domain_id)
  end

  def can?(%Claims{} = claims, :execute, %{domain_ids: [domain_id | _]}) do
    Permissions.authorized?(claims, :execute_quality_rule_implementations, domain_id)
  end

  def can?(_, :execute, _) do
    false
  end

  defp domain_id(%{domain_id: domain_id}), do: domain_id
  defp domain_id(%Implementation{rule: rule}), do: domain_id(rule)
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
