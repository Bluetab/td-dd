defmodule TdDq.Canada.ImplementationAbilities do
  @moduledoc false
  alias TdDq.Accounts.User
  alias TdDq.Permissions
  alias TdDq.Rules.Implementations.Implementation

  def can?(%User{}, action, Implementation) when action in [:index], do: true

  def can?(%User{}, action, %Implementation{}) when action in [:show],
    do: true

  def can?(
        %User{} = user,
        action,
        %Implementation{implementation_type: "raw"} = implementation
      )
      when action in [:update, :delete] do
    case implementation.rule.business_concept_id do
      nil ->
        Permissions.authorized?(user, :manage_raw_quality_rule_implementations)

      business_concept_id ->
        Permissions.authorized?(
          user,
          :manage_raw_quality_rule_implementations,
          business_concept_id
        )
    end
  end

  def can?(%User{} = user, action, %Implementation{} = implementation)
      when action in [:update, :delete] do
    case implementation.rule.business_concept_id do
      nil ->
        Permissions.authorized?(user, :manage_quality_rule_implementations)

      business_concept_id ->
        Permissions.authorized?(user, :manage_quality_rule_implementations, business_concept_id)
    end
  end

  def can?(%User{} = user, :manage_quality_rule_implementations, "") do
    Permissions.authorized?(user, :manage_quality_rule_implementations)
  end

  def can?(%User{} = user, :manage_quality_rule_implementations, business_concept_id) do
    Permissions.authorized?(user, :manage_quality_rule_implementations, business_concept_id)
  end

  def can?(%User{} = user, :manage_raw_quality_rule_implementations, "") do
    Permissions.authorized?(user, :manage_raw_quality_rule_implementations)
  end

  def can?(%User{} = user, :manage_raw_quality_rule_implementations, business_concept_id) do
    Permissions.authorized?(user, :manage_raw_quality_rule_implementations, business_concept_id)
  end
end
