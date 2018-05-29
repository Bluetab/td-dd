defmodule TdDq.Factory do
  @moduledoc false
  use ExMachina.Ecto, repo: TdDq.Repo

  def quality_control_factory do
    %TdDq.QualityControls.QualityControl {
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
      updated_by: 1
    }
  end

  def quality_rule_type_factory do
    %TdDq.QualityRules.QualityRuleType {
      name: "Quality Control Type",
      params: %{},
    }
  end

  def quality_rule_factory do
    %TdDq.QualityRules.QualityRule {
      quality_control: build(:quality_control),
      quality_rule_type: build(:quality_rule_type),
      description: "Quality Rule description",
      name: "Quality Rule name",
      type_params: %{},
      system: "Quality Rule System",
      type: "Quality Rule type",
      tag: %{}
    }
  end
end
