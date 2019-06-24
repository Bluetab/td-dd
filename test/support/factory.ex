defmodule TdDq.Factory do
  @moduledoc false
  use ExMachina.Ecto, repo: TdDq.Repo

  def rule_factory do
    %TdDq.Rules.Rule {
      business_concept_id: "Rule Business Concept Id",
      deleted_at: nil,
      description: "Rule Description",
      goal: 30,
      minimum: 12,
      name: "Rule Name",
      population: "Rule Population",
      priority: "Rule Priority",
      weight: 12,
      active: false,
      version: 1,
      updated_by: 1,
      rule_type: build(:rule_type),
      type_params: %{},
    }
  end

  def rule_type_factory do
    %TdDq.Rules.RuleType {
      name: "Rule Type",
      params: %{
        "type_params" => [],
        "system_params" => []
      },
    }
  end

  def rule_implementation_factory do
    %TdDq.Rules.RuleImplementation {
      rule: build(:rule),
      implementation_key: "implementation_key001",
      system_params: %{},
      system: "Rule Implementation System",
    }
  end

  def rule_result_factory do
    %TdDq.Rules.RuleResult {
      implementation_key: "implementation_key001",
      result: 50,
      date: Date.utc_today(),
      parent_domains: ""
    }
  end
end
