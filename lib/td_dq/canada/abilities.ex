defmodule TdDq.Canada.Abilities do
  @moduledoc false
  alias TdDq.Accounts.User
  alias TdDq.Canada.QualityControlAbilities
  alias TdDq.Canada.QualityRuleAbilities
  alias TdDq.QualityRules.QualityRule

  defimpl Canada.Can, for: User do

    def can?(%User{is_admin: true}, _action, _domain), do: true

    def can?(%User{} = user, action, QualityRule)
        when action in [:index] do
      QualityRuleAbilities.can?(user, action, QualityRule)
    end

    def can?(%User{} = user, action, %QualityRule{} = quality_rule)
        when action in [:update, :delete, :show] do
      QualityRuleAbilities.can?(user, action, quality_rule)
    end

    def can?(%User{} = user, :create_quality_rule, resource_type) do
      QualityRuleAbilities.can?(user, :create_quality_rule, resource_type)
    end

    def can?(%User{} = user, :create_quality_control, resource_type) do
      QualityControlAbilities.can?(user, :create_quality_control, resource_type)
    end

    def can?(%User{} = user, :index_quality_control, resource_type) do
      QualityControlAbilities.can?(user, :index_quality_control, resource_type)
    end

    def can?(%User{}, _action, _entity),  do: false
  end
end
