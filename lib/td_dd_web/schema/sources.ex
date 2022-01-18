defmodule TdDdWeb.Schema.Sources do
  @moduledoc """
  Absinthe schema definitions for data sources and related entities.
  """

  use Absinthe.Schema.Notation

  import Absinthe.Resolution.Helpers, only: [dataloader: 1]

  alias TdDdWeb.Resolvers

  object :source_queries do
    @desc "Get a list of data sources"
    field :sources, list_of(:source) do
      arg(:limit, :integer, default_value: 1_000)
      arg(:job_types, :string)
      resolve(&Resolvers.Sources.sources/3)
    end

    @desc "Get a data source"
    field :source, :source do
      arg(:id, non_null(:id))
      resolve(&Resolvers.Sources.source/3)
    end
  end

  object :source do
    field :id, :id
    field :external_id, :string
    field :active, :boolean
    field :type, :string
    field :config, :json, resolve: &Resolvers.Sources.config/3

    field :events, list_of(:event) do
      arg(:limit, :integer, default_value: 5)
      resolve(dataloader(TdCx.Sources))
    end

    field :template, :template do
      resolve(&Resolvers.Sources.template/3)
    end
  end

  object :event do
    field :id, :id
    field :type, :string
    field :message, :string
    field :inserted_at, :datetime
  end
end
