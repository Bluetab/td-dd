defmodule TdDdWeb.Schema.Domains do
  @moduledoc """
  Absinthe schema definitions for domains.
  """

  use Absinthe.Schema.Notation

  import Absinthe.Resolution.Helpers, only: [dataloader: 1]

  alias TdDdWeb.Resolvers

  object :domain_queries do
    @desc "Get a list of domains"
    field :domains, list_of(:domain) do
      arg(:action, :string)
      resolve(&Resolvers.Domains.domains/3)
    end
  end

  object :domain do
    field :id, non_null(:id)
    field :parent_id, :id
    field :external_id, :string
    field :name, :string

    field :actions, list_of(:string) do
      arg(:actions, list_of(:string))
      resolve(dataloader(:domain_actions))
    end
  end
end
