defmodule TdDq.Canada.RuleImplementationAbilities do
  @moduledoc false
  alias TdDq.Accounts.User
  alias TdDq.Permissions
  alias TdDq.Rules.RuleImplementation

  def can?(%User{}, action, RuleImplementation) when action in [:index], do: true

  def can?(%User{}, action, %RuleImplementation{}) when action in [:update, :delete, :show], do: true

  def can?(%User{} = user, :manage_rules, business_concept_id) do
    Permissions.authorized?(user, :manage_quality_rule, business_concept_id)
  end
end
