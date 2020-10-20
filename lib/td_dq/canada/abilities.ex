defmodule TdDq.Canada.Abilities do
  @moduledoc false

  alias TdCache.ConceptCache
  alias TdDq.Accounts.User
  alias TdDq.Canada.ImplementationAbilities
  alias TdDq.Canada.RuleAbilities
  alias TdDq.Permissions
  alias TdDq.Rules.Implementations.Implementation
  alias TdDq.Rules.Rule

  defimpl Canada.Can, for: User do
    def can?(%User{is_admin: true}, _action, _domain) do
      true
    end

    def can?(%User{} = user, action, Implementation)
        when action in [:index] do
      ImplementationAbilities.can?(user, action, Implementation)
    end

    def can?(%User{} = user, action, %Implementation{} = implementation)
        when action in [:update, :delete, :show] do
      ImplementationAbilities.can?(user, action, implementation)
    end

    def can?(%User{} = user, :manage, %{
          "business_concept_id" => nil,
          "resource_type" => "implementation"
        }) do
      ImplementationAbilities.can?(user, :manage_quality_rule_implementations, "")
    end

    def can?(%User{} = user, :manage, %{
          "business_concept_id" => business_concept_id,
          "resource_type" => "implementation"
        }) do
      ImplementationAbilities.can?(
        user,
        :manage_quality_rule_implementations,
        business_concept_id
      )
    end

    def can?(%User{} = user, :manage, Implementation) do
      ImplementationAbilities.can?(user, :manage_quality_rule_implementations, "")
    end

    def can?(%User{} = user, :manage_raw, %{
          "business_concept_id" => nil,
          "resource_type" => "implementation"
        }) do
      ImplementationAbilities.can?(user, :manage_raw_quality_rule_implementations, "")
    end

    def can?(%User{} = user, :manage_raw, %{
          "business_concept_id" => business_concept_id,
          "resource_type" => "implementation"
        }) do
      ImplementationAbilities.can?(
        user,
        :manage_raw_quality_rule_implementations,
        business_concept_id
      )
    end

    def can?(%User{} = user, :show, %Rule{business_concept_id: nil}) do
      RuleAbilities.can?(user, :show, "")
    end

    def can?(%User{} = user, :show, %Rule{business_concept_id: business_concept_id}) do
      RuleAbilities.can?(user, :show, business_concept_id) &&
        authorized?(user, business_concept_id)
    end

    def can?(%User{} = user, :create, %{
          "business_concept_id" => nil,
          "resource_type" => "implementation",
          "implementation_type" => "raw"
        }) do
      ImplementationAbilities.can?(user, :manage_raw_quality_rule_implementations, "")
    end

    def can?(%User{} = user, :create, %{
          "business_concept_id" => nil,
          "resource_type" => "implementation"
        }) do
      ImplementationAbilities.can?(user, :manage_quality_rule_implementations, "")
    end

    def can?(%User{} = user, :create, %{
          "business_concept_id" => business_concept_id,
          "resource_type" => "implementation",
          "implementation_type" => "raw"
        }) do
      ImplementationAbilities.can?(
        user,
        :manage_raw_quality_rule_implementations,
        business_concept_id
      )
    end

    def can?(%User{} = user, :create, %{
          "business_concept_id" => business_concept_id,
          "resource_type" => "implementation"
        }) do
      ImplementationAbilities.can?(
        user,
        :manage_quality_rule_implementations,
        business_concept_id
      )
    end

    def can?(%User{} = user, :update, %{
          "business_concept_id" => nil,
          "resource_type" => "implementation",
          "implementation_type" => "raw"
        }) do
      ImplementationAbilities.can?(user, :manage_raw_quality_rule_implementations, "")
    end

    def can?(%User{} = user, :update, %{
          "business_concept_id" => nil,
          "resource_type" => "implementation"
        }) do
      ImplementationAbilities.can?(user, :manage_quality_rule_implementations, "")
    end

    def can?(%User{} = user, :update, %{
          "business_concept_id" => business_concept_id,
          "resource_type" => "implementation",
          "implementation_type" => "raw"
        }) do
      ImplementationAbilities.can?(
        user,
        :manage_raw_quality_rule_implementations,
        business_concept_id
      )
    end

    def can?(%User{} = user, :update, %{
          "business_concept_id" => business_concept_id,
          "resource_type" => "implementation"
        }) do
      ImplementationAbilities.can?(
        user,
        :manage_quality_rule_implementations,
        business_concept_id
      )
    end

    def can?(%User{} = user, :delete, %{
          "business_concept_id" => nil,
          "resource_type" => "implementation",
          "implementation_type" => "raw"
        }) do
      ImplementationAbilities.can?(user, :manage_raw_quality_rule_implementations, "")
    end

    def can?(%User{} = user, :delete, %{
          "business_concept_id" => nil,
          "resource_type" => "implementation"
        }) do
      ImplementationAbilities.can?(user, :manage_quality_rule_implementations, "")
    end

    def can?(%User{} = user, :delete, %{
          "business_concept_id" => business_concept_id,
          "resource_type" => "implementation",
          "implementation_type" => "raw"
        }) do
      ImplementationAbilities.can?(
        user,
        :manage_raw_quality_rule_implementations,
        business_concept_id
      )
    end

    def can?(%User{} = user, :delete, %{
          "business_concept_id" => business_concept_id,
          "resource_type" => "implementation"
        }) do
      ImplementationAbilities.can?(
        user,
        :manage_quality_rule_implementations,
        business_concept_id
      )
    end

    def can?(%User{} = user, :execute, %{
          "business_concept_id" => nil,
          "resource_type" => "implementation"
        }) do
      ImplementationAbilities.can?(user, :execute, "")
    end

    def can?(%User{} = user, :execute, %{
          "business_concept_id" => business_concept_id,
          "resource_type" => "implementation"
        }) do
      ImplementationAbilities.can?(
        user,
        :execute,
        business_concept_id
      )
    end

    def can?(%User{} = user, :manage, %{"resource_type" => "rule"}) do
      RuleAbilities.can?(user, :manage_rules, "")
    end

    def can?(%User{} = user, :get_rules_by_concept, %{
          "business_concept_id" => business_concept_id,
          "resource_type" => "rule"
        }) do
      RuleAbilities.can?(user, :index_rule, business_concept_id) &&
        authorized?(user, business_concept_id)
    end

    def can?(%User{} = user, :create, %{
          "business_concept_id" => nil,
          "resource_type" => "rule"
        }) do
      RuleAbilities.can?(user, :manage_rules, "")
    end

    def can?(%User{} = user, :create, %{
          "business_concept_id" => business_concept_id,
          "resource_type" => "rule"
        }) do
      RuleAbilities.can?(user, :manage_rules, business_concept_id) &&
        authorized?(user, business_concept_id)
    end

    def can?(%User{} = user, :update, %{
          "business_concept_id" => nil,
          "resource_type" => "rule"
        }) do
      RuleAbilities.can?(user, :manage_rules, "")
    end

    def can?(%User{} = user, :update, %{
          "business_concept_id" => business_concept_id,
          "resource_type" => "rule"
        }) do
      RuleAbilities.can?(user, :manage_rules, business_concept_id) &&
        authorized?(user, business_concept_id)
    end

    def can?(%User{} = user, :delete, %{
          "business_concept_id" => nil,
          "resource_type" => "rule"
        }) do
      RuleAbilities.can?(user, :manage_rules, "")
    end

    def can?(%User{} = user, :delete, %{
          "business_concept_id" => business_concept_id,
          "resource_type" => "rule"
        }) do
      RuleAbilities.can?(user, :manage_rules, business_concept_id) &&
        authorized?(user, business_concept_id)
    end

    def can?(%User{}, _action, _entity), do: false

    defp authorized?(%User{} = user, business_concept_id) do
      {:ok, status} = ConceptCache.member_confidential_ids(business_concept_id)

      case status do
        1 ->
          Permissions.authorized?(
            user,
            :manage_confidential_business_concepts,
            business_concept_id
          )

        _ ->
          true
      end
    end
  end
end
