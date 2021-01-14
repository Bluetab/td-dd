defmodule TdDq.Canada.ImplementationAbilities do
  @moduledoc false
  alias TdDq.Auth.Claims
  alias TdDq.Permissions
  alias TdDq.Rules.Implementations.Implementation

  def can?(%Claims{}, action, Implementation) when action in [:index], do: true

  def can?(%Claims{}, action, %Implementation{}) when action in [:show],
    do: true

  def can?(
        %Claims{} = claims,
        action,
        %Implementation{implementation_type: "raw"} = implementation
      )
      when action in [:update, :delete] do
    case implementation.rule.business_concept_id do
      nil ->
        Permissions.authorized?(claims, :manage_raw_quality_rule_implementations)

      business_concept_id ->
        Permissions.authorized?(
          claims,
          :manage_raw_quality_rule_implementations,
          business_concept_id
        )
    end
  end

  def can?(%Claims{} = claims, action, %Implementation{} = implementation)
      when action in [:update, :delete] do
    case implementation.rule.business_concept_id do
      nil ->
        Permissions.authorized?(claims, :manage_quality_rule_implementations)

      business_concept_id ->
        Permissions.authorized?(
          claims,
          :manage_quality_rule_implementations,
          business_concept_id
        )
    end
  end

  def can?(%Claims{} = claims, :manage_quality_rule_implementations, "") do
    Permissions.authorized?(claims, :manage_quality_rule_implementations)
  end

  def can?(%Claims{} = claims, :manage_quality_rule_implementations, business_concept_id) do
    Permissions.authorized?(claims, :manage_quality_rule_implementations, business_concept_id)
  end

  def can?(%Claims{} = claims, :manage_raw_quality_rule_implementations, "") do
    Permissions.authorized?(claims, :manage_raw_quality_rule_implementations)
  end

  def can?(%Claims{} = claims, :manage_raw_quality_rule_implementations, business_concept_id) do
    Permissions.authorized?(
      claims,
      :manage_raw_quality_rule_implementations,
      business_concept_id
    )
  end

  def can?(%Claims{} = claims, :execute, "") do
    Permissions.authorized?(claims, :execute_quality_rule_implementations)
  end

  def can?(%Claims{} = claims, :execute, business_concept_id) do
    Permissions.authorized?(claims, :execute_quality_rule_implementations, business_concept_id)
  end
end
