defmodule TdDq.Canada.Abilities do
  @moduledoc false

  alias TdCache.ConceptCache
  alias TdDq.Auth.Claims
  alias TdDq.Canada.{ExecutionAbilities, ImplementationAbilities, RuleAbilities}
  alias TdDq.Executions.{Execution, Group}
  alias TdDq.Permissions
  alias TdDq.Rules.Implementations.Implementation
  alias TdDq.Rules.Rule

  defimpl Canada.Can, for: Claims do
    def can?(%Claims{role: "admin"}, _action, _domain) do
      true
    end

    def can?(%Claims{} = claims, action, target) when target in [Execution, Group] do
      ExecutionAbilities.can?(claims, action, target)
    end

    def can?(%Claims{} = claims, action, Implementation)
        when action in [:index] do
      ImplementationAbilities.can?(claims, action, Implementation)
    end

    def can?(%Claims{} = claims, action, %Implementation{} = implementation)
        when action in [:update, :delete, :show] do
      ImplementationAbilities.can?(claims, action, implementation)
    end

    def can?(%Claims{} = claims, :manage, %{
          "business_concept_id" => nil,
          "resource_type" => "implementation"
        }) do
      ImplementationAbilities.can?(claims, :manage_quality_rule_implementations, "")
    end

    def can?(%Claims{} = claims, :manage, %{
          "business_concept_id" => business_concept_id,
          "resource_type" => "implementation"
        }) do
      ImplementationAbilities.can?(
        claims,
        :manage_quality_rule_implementations,
        business_concept_id
      )
    end

    def can?(%Claims{} = claims, :manage, Implementation) do
      ImplementationAbilities.can?(claims, :manage_quality_rule_implementations, "")
    end

    def can?(%Claims{} = claims, :manage_raw, %{
          "business_concept_id" => nil,
          "resource_type" => "implementation"
        }) do
      ImplementationAbilities.can?(claims, :manage_raw_quality_rule_implementations, "")
    end

    def can?(%Claims{} = claims, :manage_raw, %{
          "business_concept_id" => business_concept_id,
          "resource_type" => "implementation"
        }) do
      ImplementationAbilities.can?(
        claims,
        :manage_raw_quality_rule_implementations,
        business_concept_id
      )
    end

    # Service account can view all rules
    def can?(%Claims{role: "service"}, :show, %Rule{}), do: true

    def can?(%Claims{} = claims, :show, %Rule{business_concept_id: nil}) do
      RuleAbilities.can?(claims, :show, "")
    end

    def can?(%Claims{} = claims, :show, %Rule{business_concept_id: business_concept_id}) do
      RuleAbilities.can?(claims, :show, business_concept_id) &&
        authorized?(claims, business_concept_id)
    end

    def can?(%Claims{} = claims, :create, %{
          "business_concept_id" => nil,
          "resource_type" => "implementation",
          "implementation_type" => "raw"
        }) do
      ImplementationAbilities.can?(claims, :manage_raw_quality_rule_implementations, "")
    end

    def can?(%Claims{} = claims, :create, %{
          "business_concept_id" => nil,
          "resource_type" => "implementation"
        }) do
      ImplementationAbilities.can?(claims, :manage_quality_rule_implementations, "")
    end

    def can?(%Claims{} = claims, :create, %{
          "business_concept_id" => business_concept_id,
          "resource_type" => "implementation",
          "implementation_type" => "raw"
        }) do
      ImplementationAbilities.can?(
        claims,
        :manage_raw_quality_rule_implementations,
        business_concept_id
      )
    end

    def can?(%Claims{} = claims, :create, %{
          "business_concept_id" => business_concept_id,
          "resource_type" => "implementation"
        }) do
      ImplementationAbilities.can?(
        claims,
        :manage_quality_rule_implementations,
        business_concept_id
      )
    end

    def can?(%Claims{} = claims, :update, %{
          "business_concept_id" => nil,
          "resource_type" => "implementation",
          "implementation_type" => "raw"
        }) do
      ImplementationAbilities.can?(claims, :manage_raw_quality_rule_implementations, "")
    end

    def can?(%Claims{} = claims, :update, %{
          "business_concept_id" => nil,
          "resource_type" => "implementation"
        }) do
      ImplementationAbilities.can?(claims, :manage_quality_rule_implementations, "")
    end

    def can?(%Claims{} = claims, :update, %{
          "business_concept_id" => business_concept_id,
          "resource_type" => "implementation",
          "implementation_type" => "raw"
        }) do
      ImplementationAbilities.can?(
        claims,
        :manage_raw_quality_rule_implementations,
        business_concept_id
      )
    end

    def can?(%Claims{} = claims, :update, %{
          "business_concept_id" => business_concept_id,
          "resource_type" => "implementation"
        }) do
      ImplementationAbilities.can?(
        claims,
        :manage_quality_rule_implementations,
        business_concept_id
      )
    end

    def can?(%Claims{} = claims, :delete, %{
          "business_concept_id" => nil,
          "resource_type" => "implementation",
          "implementation_type" => "raw"
        }) do
      ImplementationAbilities.can?(claims, :manage_raw_quality_rule_implementations, "")
    end

    def can?(%Claims{} = claims, :delete, %{
          "business_concept_id" => nil,
          "resource_type" => "implementation"
        }) do
      ImplementationAbilities.can?(claims, :manage_quality_rule_implementations, "")
    end

    def can?(%Claims{} = claims, :delete, %{
          "business_concept_id" => business_concept_id,
          "resource_type" => "implementation",
          "implementation_type" => "raw"
        }) do
      ImplementationAbilities.can?(
        claims,
        :manage_raw_quality_rule_implementations,
        business_concept_id
      )
    end

    def can?(%Claims{} = claims, :delete, %{
          "business_concept_id" => business_concept_id,
          "resource_type" => "implementation"
        }) do
      ImplementationAbilities.can?(
        claims,
        :manage_quality_rule_implementations,
        business_concept_id
      )
    end

    def can?(%Claims{} = claims, :execute, %{
          "business_concept_id" => nil,
          "resource_type" => "implementation"
        }) do
      ImplementationAbilities.can?(claims, :execute, "")
    end

    def can?(%Claims{} = claims, :execute, %{
          "business_concept_id" => business_concept_id,
          "resource_type" => "implementation"
        }) do
      ImplementationAbilities.can?(
        claims,
        :execute,
        business_concept_id
      )
    end

    def can?(%Claims{} = claims, :manage, %{"resource_type" => "rule"}) do
      RuleAbilities.can?(claims, :manage_rules, "")
    end

    def can?(%Claims{} = claims, :get_rules_by_concept, %{
          "business_concept_id" => business_concept_id,
          "resource_type" => "rule"
        }) do
      RuleAbilities.can?(claims, :index_rule, business_concept_id) &&
        authorized?(claims, business_concept_id)
    end

    def can?(%Claims{} = claims, :create, %{
          "business_concept_id" => nil,
          "resource_type" => "rule"
        }) do
      RuleAbilities.can?(claims, :manage_rules, "")
    end

    def can?(%Claims{} = claims, :create, %{
          "business_concept_id" => business_concept_id,
          "resource_type" => "rule"
        }) do
      RuleAbilities.can?(claims, :manage_rules, business_concept_id) &&
        authorized?(claims, business_concept_id)
    end

    def can?(%Claims{} = claims, :update, %{
          "business_concept_id" => nil,
          "resource_type" => "rule"
        }) do
      RuleAbilities.can?(claims, :manage_rules, "")
    end

    def can?(%Claims{} = claims, :update, %{
          "business_concept_id" => business_concept_id,
          "resource_type" => "rule"
        }) do
      RuleAbilities.can?(claims, :manage_rules, business_concept_id) &&
        authorized?(claims, business_concept_id)
    end

    def can?(%Claims{} = claims, :delete, %{
          "business_concept_id" => nil,
          "resource_type" => "rule"
        }) do
      RuleAbilities.can?(claims, :manage_rules, "")
    end

    def can?(%Claims{} = claims, :delete, %{
          "business_concept_id" => business_concept_id,
          "resource_type" => "rule"
        }) do
      RuleAbilities.can?(claims, :manage_rules, business_concept_id) &&
        authorized?(claims, business_concept_id)
    end

    def can?(%Claims{}, _action, _entity), do: false

    defp authorized?(%Claims{} = claims, business_concept_id) do
      {:ok, status} = ConceptCache.member_confidential_ids(business_concept_id)

      case status do
        1 ->
          Permissions.authorized?(
            claims,
            :manage_confidential_business_concepts,
            business_concept_id
          )

        _ ->
          true
      end
    end
  end
end
