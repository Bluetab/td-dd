defmodule TdDq.Canada.RuleImplementationAbilities do
  @moduledoc false
  alias TdDq.Accounts.User
  alias TdDq.Permissions
  alias TdDq.Rules.RuleImplementation

  def can?(%User{}, action, RuleImplementation) when action in [:index], do: true

  def can?(%User{}, action, %RuleImplementation{}) when action in [:show],
    do: true

  def can?(
        %User{} = user,
        action,
        %RuleImplementation{implementation_type: "raw"} = rule_implementation
      )
      when action in [:update, :delete] do
    case rule_implementation.rule.business_concept_id do
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

  def can?(
        %User{} = user,
        action,
        %RuleImplementation{} = rule_implementation
      )
      when action in [:update, :delete] do
    case rule_implementation.rule.business_concept_id do
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
