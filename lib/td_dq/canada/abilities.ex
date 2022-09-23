defmodule TdDq.Canada.Abilities do
  @moduledoc false

  alias TdDd.Canada.DataStructureAbilities
  alias TdDd.DataStructures.DataStructure
  alias TdDq.Auth.Claims
  alias TdDq.Canada.ExecutionAbilities
  alias TdDq.Canada.ImplementationAbilities
  alias TdDq.Canada.RuleAbilities
  alias TdDq.Canada.RuleResultAbilities
  alias TdDq.Events.QualityEvent
  alias TdDq.Executions.Execution
  alias TdDq.Executions.Group
  alias TdDq.Implementations.Implementation
  alias TdDq.Permissions
  alias TdDq.Rules.Rule
  alias TdDq.Rules.RuleResult

  defimpl Canada.Can, for: Claims do
    def can?(%Claims{} = claims, action, Implementation) do
      ImplementationAbilities.can?(claims, action, Implementation)
    end

    def can?(%Claims{} = claims, action, %Implementation{} = implementation) do
      ImplementationAbilities.can?(claims, action, implementation)
    end

    def can?(%Claims{} = claims, :execute, %{} = target) do
      ImplementationAbilities.can?(claims, :execute, target)
    end

    def can?(%Claims{} = claims, action, %Ecto.Changeset{data: %Implementation{}} = target) do
      ImplementationAbilities.can?(claims, action, target)
    end

    # admin can do anything (except some actions authorized by ImplementionAbilities)
    def can?(%Claims{role: "admin"}, _action, _domain) do
      true
    end

    def can?(%Claims{} = claims, action, target)
        when target in [Execution, Group, QualityEvent] do
      ExecutionAbilities.can?(claims, action, target)
    end

    def can?(%Claims{} = claims, action, %Execution{} = target) do
      ExecutionAbilities.can?(claims, action, target)
    end

    def can?(%Claims{} = claims, action, %Ecto.Changeset{data: %Rule{}} = target) do
      RuleAbilities.can?(claims, action, target)
    end

    def can?(%Claims{} = claims, action, Rule) do
      RuleAbilities.can?(claims, action, Rule)
    end

    def can?(%Claims{} = claims, action, %Rule{} = target) do
      RuleAbilities.can?(claims, action, target)
    end

    def can?(%Claims{} = claims, action, RuleResult) do
      RuleResultAbilities.can?(claims, action, RuleResult)
    end

    def can?(%Claims{} = claims, action, %RuleResult{} = rule_result) do
      RuleResultAbilities.can?(claims, action, rule_result)
    end

    def can?(%Claims{} = claims, action, [%RuleResult{} = rule_result | _]) do
      RuleResultAbilities.can?(claims, action, rule_result)
    end

    def can?(%Claims{} = claims, action, %{"resource_type" => "rule"} = target) do
      RuleAbilities.can?(claims, action, target)
    end

    def can?(%Claims{} = claims, :view_published_concept, domain_id) do
      Permissions.authorized?(claims, :view_published_business_concepts, domain_id)
    end

    def can?(%Claims{} = claims, action, %DataStructure{} = data_structure) do
      DataStructureAbilities.can?(claims, action, data_structure)
    end

    def can?(%Claims{}, _action, _entity), do: false
  end
end
