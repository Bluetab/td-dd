defmodule TdDdWeb.Schema.ImplementationResults do
  @moduledoc """
  Absinthe schema definitions for Implementation Results
  """

  use Absinthe.Schema.Notation

  alias TdDdWeb.Resolvers

  object :implementation_results_queries do
    @desc "get result"
    field :implementation_result, non_null(:implementation_result) do
      arg(:id, non_null(:id))
      resolve(&Resolvers.ImplementationResults.result/3)
    end
  end

  object :implementation_result do
    field :id, non_null(:id)
    field :date, :date
    field :details, :json
    field :errors, :integer
    field :has_remediation, :boolean, resolve: &Resolvers.ImplementationResults.has_remediation?/3
    field :has_segments, :boolean, resolve: &Resolvers.ImplementationResults.has_segments?/3
    field :params, :json
    field :records, :integer
    field :result_type, :string
    field :result, :string
  end
end
