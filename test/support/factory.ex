defmodule TdDq.Factory do
  @moduledoc false
  use ExMachina.Ecto, repo: TdDq.Repo

  def quality_control_factory do
    %TdDq.Rules.Rule {
      business_concept_id: "Quality Control Business Concept Id",
      description: "Quality Control Description",
      goal: 30,
      minimum: 12,
      name: "Quality Control Name",
      population: "Quality Control Population",
      priority: "Quality Control Priority",
      weight: 12,
      status: "defined",
      version: 1,
      updated_by: 1,
      type: "Quality Control Type",
      type_params: %{}
    }
  end

  def quality_rule_type_factory do
    %TdDq.Rules.RuleType {
      name: "Quality Control Type",
      params: %{
        "type_params" => [],
        "system_params" => []
      },
    }
  end

  def quality_rule_factory do
    %TdDq.Rules.RuleImplementation {
      rule: build(:quality_control),
      rule_type: build(:quality_rule_type),
      description: "Quality Rule description",
      name: "Quality Rule name",
      type: "Quality Control Type",
      system_params: %{},
      system: "Quality Rule System",
      tag: %{}
    }
  end
end
