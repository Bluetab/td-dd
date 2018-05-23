defmodule TdDq.Canada.QualityRuleAbilities do
  @moduledoc false
  alias TdDq.Accounts.User
  alias TdDq.QualityRules.QualityRule

  def can?(%User{}, action, QualityRule) when action in [:create, :index], do: true

  def can?(%User{}, action, %QualityRule{}) when action in [:update, :delete, :show], do: true

end
