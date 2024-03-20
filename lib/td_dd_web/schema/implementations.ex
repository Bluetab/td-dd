defmodule TdDdWeb.Schema.Implementations do
  @moduledoc """
  Absinthe schema definitions for Implementations
  """
  use Absinthe.Schema.Notation

  alias TdDdWeb.Resolvers

  object :implementation_queries do
    @desc "get implementation"
    field :implementation, non_null(:implementation) do
      arg(:id, non_null(:id))
      resolve(&Resolvers.Implementations.implementation/3)
    end
  end

  object :implementation_mutations do
    @desc "send implementation to approval"
    field :submit_implementation, non_null(:implementation) do
      arg(:id, non_null(:id))
      resolve(&Resolvers.Implementations.submit_implementation/3)
    end

    @desc "reject implementation"
    field :reject_implementation, non_null(:implementation) do
      arg(:id, non_null(:id))
      resolve(&Resolvers.Implementations.reject_implementation/3)
    end

    @desc "publish implementation"
    field :publish_implementation, non_null(:implementation) do
      arg(:id, non_null(:id))
      resolve(&Resolvers.Implementations.publish_implementation/3)
    end

    @desc "restore implementation"
    field :restore_implementation, non_null(:implementation) do
      arg(:id, non_null(:id))
      resolve(&Resolvers.Implementations.restore_implementation/3)
    end

    @desc "deprecate implementation"
    field :deprecate_implementation, non_null(:implementation) do
      arg(:id, non_null(:id))
      resolve(&Resolvers.Implementations.deprecate_implementation/3)
    end
  end

  object :implementation do
    field :id, non_null(:id)
    field :dataset, list_of(:dataset_row)
    field :df_content, :json
    field :df_name, :string
    field :executable, :boolean
    field :goal, :float
    field :implementation_key, :string
    field :implementation_type, :string
    field :implementation_ref, :integer
    field :minimum, :float
    field :populations, list_of(:populations)
    field :result_type, :string
    field :rule_id, :integer
    field :segments, list_of(:segment_row)
    field :validations, list_of(:condition_row)
    field :raw_content, :raw_content
    field :status, :string
    field :version, :integer
    field :versions, list_of(:implementation), resolve: &Resolvers.Implementations.versions/3
    field :results, list_of(:implementation_result), resolve: &Resolvers.Implementations.results/3
    field :updated_at, :datetime
    field :deleted_at, :datetime

    field :last_quality_event, :quality_event,
      resolve: &Resolvers.Implementations.last_quality_event/3

    field :execution_filters, list_of(:execution_filter),
      resolve: &Resolvers.Executions.executions_filters/3

    field :results_connection, :results_connection do
      arg(:first, :integer)
      arg(:last, :integer)
      arg(:after, :cursor)
      arg(:before, :cursor)
      resolve(&Resolvers.ImplementationResults.results_connection/3)
    end

    field :executions_connection, :executions_connection do
      arg(:first, :integer)
      arg(:last, :integer)
      arg(:after, :cursor)
      arg(:before, :cursor)
      arg(:filters, list_of(:execution_filter_input))
      resolve(&Resolvers.Executions.executions_connection/3)
    end
  end

  object :raw_content do
    field :dataset, non_null(:string)
    field :population, non_null(:string)
    field :validations, non_null(:string)
    field :database, :string
    field :source_id, non_null(:integer)
  end

  object :populations do
    field :populations, list_of(:condition_row)
  end

  object :dataset_row do
    field :alias, :structure_alias
    field :structure, :structure_reference
    field :clauses, list_of(:join_clause)
    field :join_type, :string
  end

  object :segment_row do
    field :structure, :structure_reference
  end

  object :join_clause do
    field :right, non_null(:structure_reference)
    field :left, non_null(:structure_reference)
  end

  object :structure_alias do
    field :index, non_null(:integer)
    field :text, :string
  end

  object :condition_row do
    field :structure, :structure_reference
    field :operator, :condition_operator
    field :modifier, :condition_modifier
  end

  object :condition_modifier do
    field :name, non_null(:string)
    field :params, non_null(:json)
  end

  object :condition_operator do
    field :name, non_null(:string)
    field :value_type, :string
    field :value_type_filter, :string
  end

  object :structure_reference do
    field :id, non_null(:id)
    field :parent_index, :integer
  end

  object :quality_event do
    field :id, non_null(:id)
    field :inserted_at, :datetime
    field :message, :string
    field :type, :string
  end

  object :execution_filter do
    field :field, :string
    field :values, list_of(:string)
  end

  input_object :execution_filter_input do
    field :field, :string
    field :values, list_of(:string)
  end
end
