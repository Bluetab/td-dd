defmodule TdDq.Canada.Abilities do
  @moduledoc false
  alias TdDq.Accounts.User
  alias TdDq.Canada.QualityControlAbilities
  alias TdDq.Canada.QualityRuleAbilities
  alias TdDq.QualityRules.QualityRule

  defimpl Canada.Can, for: User do
    def can?(%User{is_admin: true}, _action, _domain) do
      true
    end

    def can?(%User{} = user, action, QualityRule)
        when action in [:index] do
      QualityRuleAbilities.can?(user, action, QualityRule)
    end

    def can?(%User{} = user, action, %QualityRule{} = quality_rule)
        when action in [:update, :delete, :show] do
      QualityRuleAbilities.can?(user, action, quality_rule)
    end

    def can?(%User{} = user, :create, %{
          "business_concept_id" => business_concept_id,
          "resource_type" => "quality_rule"
        }) do
      QualityRuleAbilities.can?(user, :manage_quality_rule, business_concept_id)
    end

    def can?(%User{} = user, :update, %{
          "business_concept_id" => business_concept_id,
          "resource_type" => "quality_rule"
        }) do
      QualityRuleAbilities.can?(user, :manage_quality_rule, business_concept_id)
    end

    def can?(%User{} = user, :delete, %{
          "business_concept_id" => business_concept_id,
          "resource_type" => "quality_rule"
        }) do
      QualityRuleAbilities.can?(user, :manage_quality_rule, business_concept_id)
    end

    def can?(%User{} = user, :get_quality_controls_by_concept, %{
          "business_concept_id" => business_concept_id,
          "resource_type" => "quality_control"
        }) do
      QualityControlAbilities.can?(user, :index_quality_control, business_concept_id)
    end

    def can?(%User{} = user, :create, %{
          "business_concept_id" => business_concept_id,
          "resource_type" => "quality_control"
        }) do
      QualityControlAbilities.can?(user, :manage_quality_control, business_concept_id)
    end

    def can?(%User{} = user, :update, %{
          "business_concept_id" => business_concept_id,
          "resource_type" => "quality_control"
        }) do
      QualityControlAbilities.can?(user, :manage_quality_control, business_concept_id)
    end

    def can?(%User{} = user, :delete, %{
          "business_concept_id" => business_concept_id,
          "resource_type" => "quality_control"
        }) do
      QualityControlAbilities.can?(user, :manage_quality_control, business_concept_id)
    end

    def can?(%User{}, _action, _entity), do: false
  end
end
