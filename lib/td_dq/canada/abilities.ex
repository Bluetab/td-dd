defmodule TdDq.Canada.Abilities do
  @moduledoc false
  alias TdDq.Accounts.User
  alias TdDq.Canada.QualityRuleAbilities
  alias TdDq.QualityRules.QualityRule

  defimpl Canada.Can, for: User do

    def can?(%User{is_admin: true}, _action, _domain), do: true

    def can?(%User{} = user, action, QualityRule)
        when action in [:create, :index] do
      QualityRuleAbilities.can?(user, action, QualityRule)
    end

    def can?(%User{} = user, action, %QualityRule{} = quality_rule)
        when action in [:update, :delete, :show] do
      QualityRuleAbilities.can?(user, action, quality_rule)
    end

    def can?(%User{}, _action, _entity),  do: false
  end
end
