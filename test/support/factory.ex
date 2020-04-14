defmodule TdDq.Factory do
  @moduledoc false
  use ExMachina.Ecto, repo: TdDq.Repo

  def rule_factory do
    %TdDq.Rules.Rule{
      business_concept_id: "4",
      deleted_at: nil,
      description: %{"document" => "Rule Description"},
      goal: 30,
      minimum: 12,
      name: "Rule Name",
      active: false,
      version: 1,
      updated_by: 1,
      result_type: "percentage"
    }
  end

  def rule_implementation_raw_factory do
    %TdDq.Rules.RuleImplementation{
      rule: build(:rule),
      implementation_key: "implementation_key001",
      implementation_type: "raw",
      raw_content: %{
        dataset: "cliente c join address a on c.address_id=a.id",
        population: nil,
        system: 1,
        validations: "c.city = 'MADRID'"
      },
      deleted_at: nil
    }
  end

  def rule_implementation_factory do
    %TdDq.Rules.RuleImplementation{
      rule: build(:rule),
      implementation_key: "implementation_key001",
      implementation_type: "default",
      deleted_at: nil,
      raw_content: %{dataset: nil, population: nil, system: nil, validations: nil},
      dataset: [
        %{structure: %{id: 14_080}},
        %{
          structure: %{id: 3233},
          clauses: [
            %{left: %{id: 14_863}, right: %{id: 4028}}
          ],
          join_type: "inner"
        }
      ],
      population: [
        %{
          value: [%{"raw" => 8}],
          operator: %{name: "eq", value_type: "number"},
          structure: %{id: 6311}
        }
      ],
      validations: [
        %{
          value: [%{"id" => 80}],
          operator: %{name: "eq", value_type: "field"},
          structure: %{id: 800}
        }
      ]
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
