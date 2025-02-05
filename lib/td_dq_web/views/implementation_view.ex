defmodule TdDqWeb.ImplementationView do
  use TdDqWeb, :view

  alias TdCache.ConceptCache
  alias TdDfLib.Content
  alias TdDq.Implementations
  alias TdDq.Rules
  alias TdDqWeb.Implementation.ConditionsView
  alias TdDqWeb.Implementation.ConditionView
  alias TdDqWeb.Implementation.DatasetView
  alias TdDqWeb.Implementation.RawContentView
  alias TdDqWeb.Implementation.SegmentsView
  alias TdDqWeb.Implementation.StructureView
  alias TdDqWeb.ImplementationStructureView
  alias TdDqWeb.RuleResultView

  def render("index.json", %{actions: %{} = actions} = assigns) when map_size(actions) > 0 do
    "index.json"
    |> render(Map.delete(assigns, :actions))
    |> Map.put(:_actions, actions)
  end

  def render("index.json", %{implementations: implementations} = assigns) do
    %{
      data:
        render_many(implementations, __MODULE__, "implementation.json", %{
          lang: Map.get(assigns, :locale)
        })
    }
  end

  def render("show.json", %{implementation: implementation, actions: actions} = assigns) do
    %{
      data:
        render_one(implementation, __MODULE__, "implementation.json", %{
          lang: Map.get(assigns, :locale)
        }),
      _actions: actions
    }
  end

  def render("show.json", %{implementation: implementation, error: :nothing}),
    do: render("show.json", %{implementation: implementation})

  def render("show.json", %{implementation: implementation, error: error}) do
    %{
      data: render_one(implementation, __MODULE__, "implementation.json"),
      message: Atom.to_string(error)
    }
  end

  def render("show.json", %{implementation: implementation}) do
    %{data: render_one(implementation, __MODULE__, "implementation.json")}
  end

  def render(
        "implementation.json",
        %{
          implementation: %{implementation_type: "raw"} = implementation
        } = assigns
      ) do
    lang = Map.get(assigns, :lang)
    data_structures = Map.get(implementation, :data_structures)

    implementation
    |> Map.take([
      :current_business_concept_version,
      :deleted_at,
      :df_name,
      :domain,
      :domain_id,
      :event_inserted_at,
      :event_type,
      :executable,
      :execution_result_info,
      :goal,
      :id,
      :implementation_key,
      :implementation_ref,
      :implementation_type,
      :inserted_at,
      :updated_at,
      :links,
      :linked_structures_ids,
      :concepts,
      :minimum,
      :result_type,
      :rule_id,
      :structure_aliases,
      :status,
      :version,
      :structure_domain_ids,
      :structure_domains,
      :structure_links
    ])
    |> Map.put(
      :raw_content,
      render_one(implementation.raw_content, RawContentView, "raw_content.json")
    )
    |> add_rule(implementation)
    |> add_last_rule_results(implementation)
    |> add_quality_event_info(implementation)
    |> add_rule_results(implementation)
    |> maybe_render_data_structures(data_structures)
    |> add_dynamic_content(implementation)
    |> Content.legacy_content_support(:df_content)
    |> enrich_concepts(lang)
  end

  def render("implementation.json", %{implementation: implementation} = assigns) do
    data_structures = Map.get(implementation, :data_structures)
    lang = Map.get(assigns, :lang)

    implementation
    |> Map.take([
      :current_business_concept_version,
      :deleted_at,
      :df_name,
      :domain,
      :domain_id,
      :event_inserted_at,
      :event_type,
      :executable,
      :execution_result_info,
      :goal,
      :id,
      :implementation_key,
      :implementation_ref,
      :implementation_type,
      :inserted_at,
      :updated_at,
      :links,
      :linked_structures_ids,
      :concepts,
      :minimum,
      :result_type,
      :rule_id,
      :structure_aliases,
      :structure_domain_ids,
      :structure_domains,
      :status,
      :structure_links,
      :version
    ])
    |> Map.put(:dataset, render_many(implementation.dataset, DatasetView, "dataset_row.json"))
    |> enrich_concepts(lang)
    |> add_segments(implementation)
    |> add_populations(implementation)
    |> add_first_population(implementation)
    |> add_validation(implementation)
    |> add_first_validations(implementation)
    |> add_rule(implementation)
    |> add_quality_event_info(implementation)
    |> add_last_rule_results(implementation)
    |> add_rule_results(implementation)
    |> maybe_render_data_structures(data_structures)
    |> add_dynamic_content(implementation)
    |> Content.legacy_content_support(:df_content)
  end

  defp enrich_concepts(%{concepts: concepts} = implementation, lang) do
    concepts_names =
      concepts
      |> Enum.map(fn concept_id ->
        case ConceptCache.get(concept_id, lang: lang) do
          {:ok, %{name: name}} -> %{id: concept_id, name: name}
          _ -> nil
        end
      end)
      |> Enum.reject(&(&1 == nil))

    Map.put(implementation, :concepts, concepts_names)
  end

  defp enrich_concepts(implementation, _), do: implementation

  defp add_first_population(mapping, %{populations: [%{conditions: conditions} | _]})
       when is_list(conditions) do
    mapping
    |> Map.put(
      :population,
      render_many(conditions, ConditionView, "condition_row.json")
    )
  end

  defp add_first_population(mapping, _implementation), do: mapping

  defp add_populations(mapping, %{populations: populations}) when is_list(populations) do
    mapping
    |> Map.put(
      :populations,
      render_many(populations, ConditionsView, "populations.json")
    )
  end

  defp add_populations(mapping, _implementation), do: mapping

  defp add_first_validations(mapping, %{validation: [%{conditions: conditions} | _]})
       when is_list(conditions) do
    mapping
    |> Map.put(
      :validations,
      render_many(conditions, ConditionView, "condition_row.json")
    )
  end

  defp add_first_validations(mapping, _implementation), do: mapping

  defp add_validation(mapping, %{validation: validation})
       when is_list(validation) do
    mapping
    |> Map.put(
      :validation,
      render_many(validation, ConditionsView, "validation.json")
    )
  end

  defp add_validation(mapping, _implementation), do: mapping

  defp add_segments(mapping, %{segments: segments}) do
    mapping
    |> Map.put(
      :segments,
      render_many(segments, SegmentsView, "segments.json")
    )
  end

  defp add_segments(mapping, _implementation), do: mapping

  defp add_rule(mapping, %{rule: rule}) when map_size(rule) > 0 do
    rule =
      rule
      |> Map.take([:active, :name, :df_content, :df_name])
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

  defp add_dynamic_content(json, implementation) do
    df_name = Map.get(implementation, :df_name)

    content =
      implementation
      |> Map.get(:df_content)
      |> Implementations.get_cached_content(df_name)

    %{df_content: content}
    |> Map.merge(json)
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
              errors: last_rule_result.errors,
              implementation_id: implementation.id,
              result_type: last_rule_result.result_type,
              records: last_rule_result.records,
              params: last_rule_result.params,
              minimum: last_rule_result.minimum,
              goal: last_rule_result.goal
            }
          ]
      end

    implementation_mapping
    |> Map.put(:results, rule_results_mappings)
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

  defp add_rule_results(implementation_mapping, %{results: [_ | _] = results}) do
    rule_results =
      results
      |> Enum.sort_by(& &1.date, {:desc, DateTime})
      |> Enum.map(&render_one(&1, RuleResultView, "rule_result.json"))

    Map.put(implementation_mapping, :results, rule_results)
  end

  defp add_rule_results(implementation_mapping, _), do: implementation_mapping

  defp maybe_render_data_structures(implementation_mapping, data_structures)
       when is_list(data_structures) do
    Map.put(
      implementation_mapping,
      :data_structures,
      render_many(data_structures, ImplementationStructureView, "implementation_structure.json")
    )
  end

  defp maybe_render_data_structures(implementation_mapping, _), do: implementation_mapping
end

defmodule TdDqWeb.Implementation.RawContentView do
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

  defp with_parent_index(structure_json, %{parent_index: nil}), do: structure_json

  defp with_parent_index(structure_json, %{parent_index: parent_index}) do
    Map.put(structure_json, :parent_index, parent_index)
  end

  defp with_parent_index(structure_json, _), do: structure_json

  defp with_headers(structure_json, %{headers: headers}) do
    Map.put(structure_json, :headers, headers)
  end

  defp with_headers(structure_json, _), do: structure_json

  def render("structure.json", %{structure: structure}) do
    structure
    |> Map.take([:alias, :external_id, :id, :metadata, :name, :path, :system, :type])
    |> with_parent_index(structure)
    |> with_headers(structure)
  end
end

defmodule TdDqWeb.Implementation.StructureAliasView do
  use TdDqWeb, :view

  def render("structure_alias.json", %{structure_alias: structure_alias}) do
    %{
      index: Map.get(structure_alias, :index),
      text: Map.get(structure_alias, :text)
    }
  end
end

defmodule TdDqWeb.Implementation.DatasetView do
  use TdDqWeb, :view

  alias TdDqWeb.Implementation.JoinClauseView
  alias TdDqWeb.Implementation.StructureAliasView
  alias TdDqWeb.Implementation.StructureView

  def render("dataset_row.json", %{dataset: %{structure: structure} = dataset_row}) do
    case dataset_row.clauses do
      nil ->
        %{
          structure: render_one(structure, StructureView, "structure.json"),
          alias:
            render_one(Map.get(dataset_row, :alias), StructureAliasView, "structure_alias.json")
        }

      _ ->
        %{
          structure: render_one(structure, StructureView, "structure.json"),
          alias:
            render_one(Map.get(dataset_row, :alias), StructureAliasView, "structure_alias.json"),
          clauses: render_many(dataset_row.clauses, JoinClauseView, "join_clause_row.json"),
          join_type: dataset_row.join_type
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

  alias TdDqWeb.Implementation.ModifierView
  alias TdDqWeb.Implementation.OperatorView
  alias TdDqWeb.Implementation.StructureView

  def render("condition_row.json", %{condition: row}) do
    %{
      structure: render_one(row.structure, StructureView, "structure.json"),
      operator: render_one(row.operator, OperatorView, "operator.json"),
      value: row.value
    }
    |> with_population(row)
    |> with_modifier(row)
    |> with_value_modifier(row)
  end

  defp with_population(condition, %{population: population = [_ | _]}) do
    Map.put(condition, :population, render_many(population, __MODULE__, "condition_row.json"))
  end

  defp with_population(condition, _row), do: condition

  defp with_modifier(condition, %{modifier: modifier = %{}}) do
    Map.put(condition, :modifier, render_one(modifier, ModifierView, "modifier.json"))
  end

  defp with_modifier(condition, _row), do: condition

  defp with_value_modifier(condition, %{value_modifier: value_modifier = [_ | _]}) do
    Map.put(
      condition,
      :value_modifier,
      render_many(value_modifier, ModifierView, "modifier.json")
    )
  end

  defp with_value_modifier(condition, _row), do: condition
end

defmodule TdDqWeb.Implementation.SegmentsView do
  use TdDqWeb, :view

  alias TdDqWeb.Implementation.StructureView

  def render("segments.json", %{segments: row}) do
    %{
      structure: render_one(row.structure, StructureView, "structure.json")
    }
  end
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

defmodule TdDqWeb.Implementation.ModifierView do
  use TdDqWeb, :view

  def render("modifier.json", %{modifier: modifier}) do
    %{
      name: modifier.name,
      params: modifier.params
    }
  end
end

defmodule TdDqWeb.Implementation.ConditionsView do
  use TdDqWeb, :view

  alias TdDqWeb.Implementation.ConditionView

  def render(_, %{conditions: %{conditions: conditions}}) do
    render_many(conditions, ConditionView, "condition_row.json")
  end
end
