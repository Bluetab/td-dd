defmodule TdDq.Factory do
  @moduledoc """
  An `ExMachina` factory for data quality tests.
  """

  use ExMachina.Ecto, repo: TdDq.Repo
  use TdDfLib.TemplateFactory

  def rule_factory do
    %TdDq.Rules.Rule{
      business_concept_id: sequence(:business_concept_id, &"#{&1}"),
      description: %{"document" => "Rule Description"},
      goal: 30,
      minimum: 12,
      name: sequence("rule_name"),
      active: false,
      version: 1,
      updated_by: sequence(:updated_by, & &1),
      result_type: "percentage"
    }
  end

  def raw_implementation_factory do
    %TdDq.Rules.Implementations.Implementation{
      rule: build(:rule),
      implementation_key: sequence("ri"),
      implementation_type: "raw",
      raw_content: build(:raw_content),
      deleted_at: nil
    }
  end

  def raw_content_factory do
    %TdDq.Rules.Implementations.RawContent{
      dataset: "clientes c join address a on c.address_id=a.id",
      population: "a.country = 'SPAIN'",
      system: 1,
      validations: "a.city is null"
    }
  end

  def implementation_factory(attrs) do
    attrs = default_assoc(attrs, :rule_id, :rule)

    %TdDq.Rules.Implementations.Implementation{
      implementation_key: sequence("implementation_key"),
      implementation_type: "default",
      dataset: build(:dataset),
      population: build(:population),
      validations: build(:validations)
    }
    |> merge_attributes(attrs)
  end

  def dataset_factory(_attrs) do
    [
      build(:dataset_row),
      build(:dataset_row, clauses: [build(:dataset_clause)], join_type: "inner")
    ]
  end

  def dataset_row_factory do
    %TdDq.Rules.Implementations.DatasetRow{
      structure: build(:dataset_structure)
    }
  end

  def dataset_structure_factory do
    %TdDq.Rules.Implementations.Structure{
      id: sequence(:dataset_structure_id, &(&1 + 14_080))
    }
  end

  def dataset_clause_factory do
    %TdDq.Rules.Implementations.JoinClause{
      left: build(:dataset_structure),
      right: build(:dataset_structure)
    }
  end

  def population_factory(_attrs) do
    [build(:condition_row)]
  end

  def validations_factory(_attrs) do
    [build(:condition_row)]
  end

  def condition_row_factory do
    %TdDq.Rules.Implementations.ConditionRow{
      value: [%{"raw" => 8}],
      operator: build(:operator),
      structure: build(:dataset_structure)
    }
  end

  def operator_factory do
    %TdDq.Rules.Implementations.Operator{name: "eq", value_type: "number"}
  end

  def rule_result_factory do
    %TdDq.Rules.RuleResult{
      implementation_key: sequence("ri"),
      result: "#{Decimal.round(50, 2)}",
      date: "#{DateTime.utc_now()}"
    }
  end

  def rule_result_record_factory(attrs) do
    %{
      implementation_key: sequence("ri"),
      date: "2020-02-02T00:00:00Z",
      result: "0",
      records: "",
      errors: ""
    }
    |> merge_attributes(attrs)
    |> Enum.reject(fn {_k, v} -> v == "" end)
    |> Map.new()
  end

  def execution_factory do
    %TdDq.Executions.Execution{}
  end

  def execution_group_factory do
    %TdDq.Executions.Group{
      created_by_id: 0
    }
  end

  def claims_factory(attrs) do
    %TdDq.Auth.Claims{
      user_id: sequence(:user_id, & &1),
      user_name: sequence("user_name"),
      role: "admin",
      jti: sequence("jti")
    }
    |> merge_attributes(attrs)
  end

  def domain_factory do
    %{
      name: sequence("domain_name"),
      id: sequence(:domain_id, & &1),
      updated_at: DateTime.utc_now()
    }
  end

  defp default_assoc(attrs, id_key, key) do
    if Enum.any?([key, id_key], &Map.has_key?(attrs, &1)) do
      attrs
    else
      Map.put(attrs, key, build(key))
    end
  end
end
