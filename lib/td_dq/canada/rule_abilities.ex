defmodule TdDq.Canada.RuleAbilities do
  @moduledoc false
  alias TdDq.Accounts.User
  alias TdDq.Permissions

  def can?(%User{} = _user, :index_rule, _business_concept_id), do: true

  def can?(%User{} = user, :show, "") do
    Permissions.authorized?(user, :view_quality_rule)
  end

  def can?(%User{} = user, :manage_rules, "") do
    Permissions.authorized?(user, :manage_quality_rule)
  end

  def can?(%User{} = user, :show, business_concept_id) do
    Permissions.authorized?(user, :view_quality_rule, business_concept_id)
  end

  def can?(%User{} = user, :manage_rules, business_concept_id) do
    Permissions.authorized?(user, :manage_quality_rule, business_concept_id)
  end
end
