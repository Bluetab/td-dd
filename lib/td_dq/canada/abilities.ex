defmodule TdDq.Canada.Abilities do
  @moduledoc false

  alias TdDq.Auth.Claims
  alias TdDq.Canada.ExecutionAbilities
  alias TdDq.Canada.ImplementationAbilities
  alias TdDq.Canada.RuleAbilities
  alias TdDq.Events.QualityEvent
  alias TdDq.Executions.Execution
  alias TdDq.Executions.Group
  alias TdDq.Implementations.Implementation
  alias TdDq.Rules.Rule

  defimpl Canada.Can, for: Claims do
    # admin can do anything
    def can?(%Claims{role: "admin"}, _action, _domain), do: true

    def can?(%Claims{} = claims, action, target)
        when target in [Execution, Group, QualityEvent] do
      ExecutionAbilities.can?(claims, action, target)
    end

    def can?(%Claims{} = claims, action, %Execution{} = target) do
      ExecutionAbilities.can?(claims, action, target)
    end

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

    def can?(%Claims{} = claims, action, %Ecto.Changeset{data: %Rule{}} = target) do
      RuleAbilities.can?(claims, action, target)
    end

    def can?(%Claims{} = claims, action, Rule) do
      RuleAbilities.can?(claims, action, Rule)
    end

    def can?(%Claims{} = claims, action, %Rule{} = target) do
      RuleAbilities.can?(claims, action, target)
    end

    def can?(%Claims{} = claims, action, %{"resource_type" => "rule"} = target) do
      RuleAbilities.can?(claims, action, target)
    end

    def can?(%Claims{}, _action, _entity), do: false
  end
end
