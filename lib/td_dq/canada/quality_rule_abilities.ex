defmodule TdDq.Canada.QualityRuleAbilities do
  @moduledoc false
  alias TdDq.Accounts.User
  alias TdDq.Permissions
  alias TdDq.QualityRules.QualityRule

  def can?(%User{}, action, QualityRule) when action in [:index], do: true

  def can?(%User{}, action, %QualityRule{}) when action in [:update, :delete, :show], do: true

  def can?(%User{} = user, :create_quality_rule, %{"business_concept_id" => business_concept_id}) do
    Permissions.authorized?(user, :create_quality_rule, business_concept_id)
  end
end
