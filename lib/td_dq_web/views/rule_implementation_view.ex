defmodule TdDqWeb.RuleImplementationView do
  use TdDqWeb, :view
  alias TdDqWeb.RuleImplementation.ConditionView
  alias TdDqWeb.RuleImplementation.DatasetView
  alias TdDqWeb.RuleImplementation.RawContent
  alias TdDqWeb.RuleImplementationView
  alias TdDqWeb.RuleResultView

  def render("index.json", %{rule_implementations: rule_implementations}) do
    %{data: render_many(rule_implementations, RuleImplementationView, "rule_implementation.json")}
  end

  def render("show.json", %{rule_implementation: rule_implementation}) do
    %{data: render_one(rule_implementation, RuleImplementationView, "rule_implementation.json")}
  end

  def render("rule_implementation.json", %{
        rule_implementation: %{implementation_type: "raw"} = rule_implementation
      }) do
    %{
      id: rule_implementation.id,
      rule_id: rule_implementation.rule_id,
      implementation_key: rule_implementation.implementation_key,
      implementation_type: rule_implementation.implementation_type,
      raw_content: render_one(rule_implementation.raw_content, RawContent, "raw_content.json"),
      deleted_at: rule_implementation.deleted_at
    }
    |> add_rule(rule_implementation)
    |> add_last_rule_results(rule_implementation)
    |> add_rule_results(rule_implementation)
  end

  def render("rule_implementation.json", %{rule_implementation: rule_implementation}) do
    %{
      id: rule_implementation.id,
      rule_id: rule_implementation.rule_id,
      implementation_key: rule_implementation.implementation_key,
      implementation_type: rule_implementation.implementation_type,
      dataset: render_many(rule_implementation.dataset, DatasetView, "dataset_row.json"),
      population:
        render_many(rule_implementation.population, ConditionView, "condition_row.json"),
      validations:
        render_many(rule_implementation.validations, ConditionView, "condition_row.json"),
      deleted_at: rule_implementation.deleted_at
    }
    |> add_rule(rule_implementation)
    |> add_last_rule_results(rule_implementation)
    |> add_rule_results(rule_implementation)
  end

  defp add_rule(rule_implementation_mapping, rule_implementation) do
    case Ecto.assoc_loaded?(rule_implementation.rule) do
      true ->
        rule = rule_implementation.rule

        rule_mapping = %{
          name: rule.name,
          minimum: rule.minimum,
          goal: rule.goal,
          result_type: rule.result_type
        }

        Map.put(rule_implementation_mapping, :rule, rule_mapping)

      _ ->
        rule_implementation_mapping
    end
  end

  defp add_last_rule_results(rule_implementation_mapping, rule_implementation) do
    rule_results_mappings =
      case Map.get(rule_implementation, :_last_rule_result_, nil) do
        nil ->
          []

        last_rule_result ->
          [
            %{
              result: last_rule_result.result,
              date: last_rule_result.date,
              errors: last_rule_result.errors
            }
          ]
      end

    rule_implementation_mapping
    |> Map.put(:rule_results, rule_results_mappings)
  end

  defp add_rule_results(rule_implementation_mapping, rule_implementation) do
    all_rule_results_mappings =
      rule_implementation
      |> Map.get(:all_rule_results, [])
      |> Enum.map(&Map.from_struct(&1))
      |> Enum.map(&render_one(&1, RuleResultView, "rule_result.json"))

    case all_rule_results_mappings do
      [] -> rule_implementation_mapping
      _ -> Map.put(rule_implementation_mapping, :all_rule_results, all_rule_results_mappings)
    end
  end
end

defmodule TdDqWeb.RuleImplementation.RawContent do
  use TdDqWeb, :view

  def render("raw_content.json", %{raw_content: raw_content}) do
    %{
      system: Map.get(raw_content, :system),
      structure_alias: Map.get(raw_content, :structure_alias),
      dataset: Map.get(raw_content, :dataset),
      population: Map.get(raw_content, :population),
      validations: Map.get(raw_content, :validations)
    }
  end
end

defmodule TdDqWeb.RuleImplementation.StructureView do
  use TdDqWeb, :view

  def render("structure.json", %{structure: structure}) do
    %{
      id: Map.get(structure, :id),
      name: Map.get(structure, :name),
      path: Map.get(structure, :path),
      system: Map.get(structure, :system),
      external_id: Map.get(structure, :external_id),
      type: Map.get(structure, :type),
      metadata: Map.get(structure, :metadata)
    }
  end
end

defmodule TdDqWeb.RuleImplementation.DatasetView do
  use TdDqWeb, :view

  alias TdDqWeb.RuleImplementation.JoinClauseView
  alias TdDqWeb.RuleImplementation.StructureView

  def render("dataset_row.json", %{dataset: %{structure: structure} = dataset_row}) do
    case dataset_row.clauses do
      nil ->
        %{
          structure: render_one(structure, StructureView, "structure.json")
        }

      _ ->
        %{
          structure: render_one(structure, StructureView, "structure.json"),
          clauses: render_many(dataset_row.clauses, JoinClauseView, "join_clause_row.json")
        }
    end
  end
end

defmodule TdDqWeb.RuleImplementation.JoinClauseView do
  use TdDqWeb, :view

  alias TdDqWeb.RuleImplementation.StructureView

  def render("join_clause_row.json", %{join_clause: join_clause_row}) do
    %{
      left: render_one(join_clause_row.left, StructureView, "structure.json"),
      right: render_one(join_clause_row.right, StructureView, "structure.json")
    }
  end
end

defmodule TdDqWeb.RuleImplementation.ConditionView do
  use TdDqWeb, :view

  alias TdDqWeb.RuleImplementation.OperatorView
  alias TdDqWeb.RuleImplementation.StructureView

  def render("condition_row.json", %{condition: row}) do
    %{
      structure: render_one(row.structure, StructureView, "structure.json"),
      operator: render_one(row.operator, OperatorView, "operator.json"),
      value: row.value
    }
  end
end

defmodule TdDqWeb.RuleImplementation.OperatorView do
  use TdDqWeb, :view

  def render("operator.json", %{operator: %{value_type_filter: nil} = operator}) do
    %{
      name: operator.name,
      value_type: operator.value_type
    }
  end

  def render("operator.json", %{operator: operator}) do
    %{
      name: operator.name,
      value_type: operator.value_type,
      value_type_filter: operator.value_type_filter
    }
  end
end
