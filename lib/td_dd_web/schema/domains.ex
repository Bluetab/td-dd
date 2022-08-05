defmodule TdDdWeb.Schema.Domains do
  @moduledoc """
  Absinthe schema definitions for domains.
  """

  use Absinthe.Schema.Notation

  alias TdDdWeb.Resolvers

  object :domain_queries do
    @desc "Get a list of domains"
    field :domains, list_of(:domain) do
      arg(:action, :string)
      arg(:ids, list_of(:id))
      resolve(&Resolvers.Domains.domains/3)
    end
  end

  object :domain do
    field :id, non_null(:id)
    field :parent_id, :id
    field :external_id, :string
    field :name, :string
  end
end
