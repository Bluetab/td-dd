defmodule TdDq.Canada.RuleAbilities do
  @moduledoc false
  alias TdDq.Auth.Claims
  alias TdDq.Permissions

  def can?(%Claims{}, :index_rule, _business_concept_id), do: true

  def can?(%Claims{} = claims, :show, "") do
    Permissions.authorized?(claims, :view_quality_rule)
  end

  def can?(%Claims{} = claims, :manage_rules, "") do
    Permissions.authorized?(claims, :manage_quality_rule)
  end

  def can?(%Claims{} = claims, :show, business_concept_id) do
    Permissions.authorized?(claims, :view_quality_rule, business_concept_id)
  end

  def can?(%Claims{} = claims, :manage_rules, business_concept_id) do
    Permissions.authorized?(claims, :manage_quality_rule, business_concept_id)
  end
end
