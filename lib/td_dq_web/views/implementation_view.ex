defmodule TdDqWeb.ImplementationView do
  use TdDqWeb, :view

  alias TdDq.Rules
  alias TdDqWeb.Implementation.ConditionView
  alias TdDqWeb.Implementation.DatasetView
  alias TdDqWeb.Implementation.RawContent
  alias TdDqWeb.RuleResultView

  def render("index.json", %{implementations: implementations}) do
    %{data: render_many(implementations, __MODULE__, "implementation.json")}
  end

  def render("show.json", %{implementation: implementation}) do
    %{data: render_one(implementation, __MODULE__, "implementation.json")}
  end

  def render("implementation.json", %{
        implementation: %{implementation_type: "raw"} = implementation
      }) do
    implementation
    |> Map.take([
      :current_business_concept_version,
      :id,
      :rule_id,
      :implementation_key,
      :implementation_type,
      :deleted_at,
      :execution_result_info,
      :structure_aliases,
      :df_name,
      :df_content,
      :executable,
      :event_type,
      :event_inserted_at
    ])
    |> Map.put(
      :raw_content,
      render_one(implementation.raw_content, RawContent, "raw_content.json")
    )
    |> add_rule(implementation)
    |> add_last_rule_results(implementation)
    |> add_quality_event_info(implementation)
    |> add_rule_results(implementation)
  end

  def render("implementation.json", %{implementation: implementation}) do
    implementation
    |> Map.take([
      :current_business_concept_version,
      :id,
      :rule_id,
      :implementation_key,
      :implementation_type,
      :deleted_at,
      :execution_result_info,
      :structure_aliases,
      :df_name,
      :df_content,
      :executable,
      :event_type,
      :event_inserted_at
    ])
    |> Map.put(:dataset, render_many(implementation.dataset, DatasetView, "dataset_row.json"))
    |> Map.put(
      :population,
      render_many(implementation.population, ConditionView, "condition_row.json")
    )
    |> Map.put(
      :validations,
      render_many(implementation.validations, ConditionView, "condition_row.json")
    )
    |> add_rule(implementation)
    |> add_quality_event_info(implementation)
    |> add_last_rule_results(implementation)
    |> add_rule_results(implementation)
  end

  defp add_rule(mapping, %{rule: rule}) when map_size(rule) > 0 do
    rule =
      rule
      |> Map.take([:active, :goal, :name, :minimum, :result_type, :df_content, :df_name])
      |> add_dynamic_content()

    Map.put(mapping, :rule, rule)
  end

  defp add_rule(mapping, _implementation), do: mapping

  defp add_dynamic_content(rule) do
    df_name = Map.get(rule, :df_name)

    content =
      rule
      |> Map.get(:df_content)
      |> Rules.get_cached_content(df_name)

    Map.put(rule, :df_content, content)
  end

  defp add_last_rule_results(implementation_mapping, implementation) do
    rule_results_mappings =
      case Map.get(implementation, :_last_rule_result_, nil) do
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

    implementation_mapping
    |> Map.put(:rule_results, rule_results_mappings)
  end

  defp add_quality_event_info(implementation_mapping, implementation) do
    case Map.get(implementation, :quality_event, nil) do
      nil ->
        implementation_mapping

      quality_event ->
        implementation_mapping
        |> Map.put(:event_type, quality_event.type)
        |> Map.put(:event_message, quality_event.message)
        |> Map.put(:event_inserted_at, quality_event.inserted_at)
    end
  end

  defp add_rule_results(implementation_mapping, implementation) do
    all_rule_results_mappings =
      implementation
      |> Map.get(:all_rule_results, [])
      |> Enum.map(&render_one(&1, RuleResultView, "rule_result.json"))

    case all_rule_results_mappings do
      [] -> implementation_mapping
      _ -> Map.put(implementation_mapping, :all_rule_results, all_rule_results_mappings)
    end
  end
end

defmodule TdDqWeb.Implementation.RawContent do
  use TdDqWeb, :view

  def render("raw_content.json", %{raw_content: %{} = raw_content}) do
    source =
      case Map.get(raw_content, :source) do
        %{external_id: external_id} -> %{external_id: external_id}
        _ -> %{}
      end

    raw_content
    |> Map.take([:source_id, :database, :dataset, :population, :validations])
    |> Map.put(:source, source)
  end
end

defmodule TdDqWeb.Implementation.StructureView do
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

defmodule TdDqWeb.Implementation.DatasetView do
  use TdDqWeb, :view

  alias TdDqWeb.Implementation.JoinClauseView
  alias TdDqWeb.Implementation.StructureView

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

defmodule TdDqWeb.Implementation.JoinClauseView do
  use TdDqWeb, :view

  alias TdDqWeb.Implementation.StructureView

  def render("join_clause_row.json", %{join_clause: join_clause_row}) do
    %{
      left: render_one(join_clause_row.left, StructureView, "structure.json"),
      right: render_one(join_clause_row.right, StructureView, "structure.json")
    }
  end
end

defmodule TdDqWeb.Implementation.ConditionView do
  use TdDqWeb, :view

  alias TdDqWeb.Implementation.OperatorView
  alias TdDqWeb.Implementation.StructureView

  def render("condition_row.json", %{condition: row}) do
    %{
      structure: render_one(row.structure, StructureView, "structure.json"),
      operator: render_one(row.operator, OperatorView, "operator.json"),
      value: row.value
    }
    |> with_population()
  end

  defp with_population(%{population: population} = condition) do
    %{condition | population: render_many(population, __MODULE__, "condition_row.json")}
  end

  defp with_population(condition), do: condition
end

defmodule TdDqWeb.Implementation.OperatorView do
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
