defmodule TdDdWeb.Schema.Rules do
  @moduledoc """
  Absinthe schema definitions for quality rules and related entities.
  """

  use Absinthe.Schema.Notation

  alias TdDdWeb.Resolvers

  object :rule_queries do
    @desc "Get a list of rules"
    field :rules, list_of(:rule) do
      arg(:query, :string)
      resolve(&Resolvers.Rules.rules/3)
    end
  end

  object :rule do
    field :id, non_null(:id)
    field :name, non_null(:string)
    field :domain, :domain
  end
end
