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

    def can?(%User{} = user, action, %RuleImplementation{} = quality_rule)
        when action in [:update, :delete, :show] do
      RuleImplementationAbilities.can?(user, action, quality_rule)
    end

    def can?(%User{} = user, :create, %{
          "business_concept_id" => business_concept_id,
          "resource_type" => "quality_rule"
        }) do
      RuleImplementationAbilities.can?(user, :manage_rules, business_concept_id)
    end

    def can?(%User{} = user, :update, %{
          "business_concept_id" => business_concept_id,
          "resource_type" => "quality_rule"
        }) do
      RuleImplementationAbilities.can?(user, :manage_rules, business_concept_id)
    end

    def can?(%User{} = user, :delete, %{
          "business_concept_id" => business_concept_id,
          "resource_type" => "quality_rule"
        }) do
      RuleImplementationAbilities.can?(user, :manage_rules, business_concept_id)
    end

    def can?(%User{} = user, :get_quality_controls_by_concept, %{
          "business_concept_id" => business_concept_id,
          "resource_type" => "quality_control"
        }) do
      RuleAbilities.can?(user, :index_rule, business_concept_id)
    end

    def can?(%User{} = user, :create, %{
          "business_concept_id" => business_concept_id,
          "resource_type" => "quality_control"
        }) do
      RuleAbilities.can?(user, :manage_rules, business_concept_id)
    end

    def can?(%User{} = user, :update, %{
          "business_concept_id" => business_concept_id,
          "resource_type" => "quality_control"
        }) do
      RuleAbilities.can?(user, :manage_rules, business_concept_id)
    end

    def can?(%User{} = user, :delete, %{
          "business_concept_id" => business_concept_id,
          "resource_type" => "quality_control"
        }) do
      RuleAbilities.can?(user, :manage_rules, business_concept_id)
    end

    def can?(%User{}, _action, _entity), do: false
  end
end
