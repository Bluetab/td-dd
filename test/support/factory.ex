defmodule TdDq.Factory do
  @moduledoc false
  use ExMachina.Ecto, repo: TdDq.Repo

  def rule_factory do
    %TdDq.Rules.Rule{
      business_concept_id: "Rule Business Concept Id",
      deleted_at: nil,
      description: %{"document" => "Rule Description"},
      goal: 30,
      minimum: 12,
      name: "Rule Name",
      active: false,
      version: 1,
      updated_by: 1,
      rule_type: build(:rule_type),
      type_params: %{},
      result_type: "percentage"
    }
  end

  def rule_type_factory do
    %TdDq.Rules.RuleType{
      name: "Rule Type",
      params: %{
        "type_params" => [],
        "system_params" => []
      }
    }
  end

  def structure_rule_type_factory do
    %TdDq.Rules.RuleType{
      name: "Rule Type",
      params: %{
        "type_params" => [],
        "system_params" => [
          %{"name" => "system_required", "type" => "boolean", "value" => false, "hidden" => true}
        ]
      }
    }
  end

  def rule_implementation_factory do
    %TdDq.Rules.RuleImplementation{
      rule: build(:rule),
      implementation_key: "implementation_key001",
      system_params: %{},
      system: "Rule Implementation System",
      deleted_at: nil
    }
  end

  def rule_result_factory do
    %TdDq.Rules.RuleResult{
      implementation_key: "implementation_key001",
      result: 50,
      date: DateTime.utc_now(),
      parent_domains: ""
    }
  end

  def user_factory do
    %TdDq.Accounts.User{
      id: 0,
      user_name: "bufoncillo",
      is_admin: false
    }
  end

  def user_admin_factory do
    %TdDq.Accounts.User{
      id: 1,
      user_name: "bufoncillo_admin",
      is_admin: true
    }
  end
end
