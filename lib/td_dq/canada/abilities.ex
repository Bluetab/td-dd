defmodule TdDq.Canada.Abilities do
  @moduledoc false
  alias TdDq.Accounts.User
  alias TdDq.Canada.RuleAbilities
  alias TdDq.Canada.RuleImplementationAbilities
  alias TdDq.Rules.RuleImplementation

  defimpl Canada.Can, for: User do
    def can?(%User{is_admin: true}, _action, _domain) do
      true
    end

    def can?(%User{} = user, action, RuleImplementation)
        when action in [:index] do
      RuleImplementationAbilities.can?(user, action, RuleImplementation)
    end

    def can?(%User{} = user, action, %RuleImplementation{} = rule_implementation)
        when action in [:update, :delete, :show] do
      RuleImplementationAbilities.can?(user, action, rule_implementation)
    end

    def can?(%User{} = user, :create, %{
          "business_concept_id" => business_concept_id,
          "rule_type" => rule_type,
          "resource_type" => "rule_implementation"
        }) do
          rule_type !== "custom_validation" &&
          RuleImplementationAbilities.can?(user, :manage_rules, business_concept_id)
    end

    def can?(%User{} = user, :update, %{
          "business_concept_id" => business_concept_id,
          "resource_type" => "rule_implementation"
        }) do
      RuleImplementationAbilities.can?(user, :manage_rules, business_concept_id)
    end

    def can?(%User{} = user, :delete, %{
          "business_concept_id" => business_concept_id,
          "resource_type" => "rule_implementation"
        }) do
      RuleImplementationAbilities.can?(user, :manage_rules, business_concept_id)
    end

    def can?(%User{} = user, :get_rules_by_concept, %{
          "business_concept_id" => business_concept_id,
          "resource_type" => "rule"
        }) do
      RuleAbilities.can?(user, :index_rule, business_concept_id)
    end

    def can?(%User{} = user, :create, %{
          "business_concept_id" => business_concept_id,
          "resource_type" => "rule"
        }) do
      RuleAbilities.can?(user, :manage_rules, business_concept_id)
    end

    def can?(%User{} = user, :update, %{
          "business_concept_id" => business_concept_id,
          "resource_type" => "rule"
        }) do
      RuleAbilities.can?(user, :manage_rules, business_concept_id)
    end

    def can?(%User{} = user, :delete, %{
          "business_concept_id" => business_concept_id,
          "resource_type" => "rule"
        }) do
      RuleAbilities.can?(user, :manage_rules, business_concept_id)
    end

    def can?(%User{}, _action, _entity), do: false
  end
end
