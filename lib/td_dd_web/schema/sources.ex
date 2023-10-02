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
      arg(:deleted, :boolean, default_value: false)
      arg(:job_types, :string)
      resolve(&Resolvers.Sources.sources/3)
    end

    @desc "Get a data source"
    field :source, :source do
      arg(:id, :id)
      arg(:external_id, :string)
      resolve(&Resolvers.Sources.source/3)
    end
  end

  object :source_mutations do
    @desc "Disables an active data source"
    field :disable_source, non_null(:source) do
      arg(:id, non_null(:id))
      resolve(&Resolvers.Sources.disable_source/3)
    end

    @desc "Enables an inactive data source"
    field :enable_source, non_null(:source) do
      arg(:id, non_null(:id))
      resolve(&Resolvers.Sources.enable_source/3)
    end

    @desc "Deletes a data source"
    field :delete_source, non_null(:source) do
      arg(:id, non_null(:id))
      resolve(&Resolvers.Sources.delete_source/3)
    end

    @desc "Creates a new data source"
    field :create_source, non_null(:source) do
      arg(:source, non_null(:create_source_input))
      resolve(&Resolvers.Sources.create_source/3)
    end

    @desc "Updates an existing data source"
    field :update_source, non_null(:source) do
      arg(:source, non_null(:update_source_input))
      resolve(&Resolvers.Sources.update_source/3)
      middleware(Crudry.Middlewares.TranslateErrors)
    end
  end

  input_object :create_source_input do
    field :external_id, non_null(:string)
    field :type, non_null(:string)
    field :config, :json
  end

  input_object :update_source_input do
    field :id, non_null(:id)
    field :external_id, :string
    field :type, :string
    field :config, :json
    field :merge, :boolean
  end

  object :source do
    field :id, :id
    field :external_id, :string
    field :active, :boolean
    field :type, :string
    field :job_types, list_of(:string), resolve: &Resolvers.Sources.job_types/3
    field :config, :json

    field :events, list_of(:event) do
      arg(:limit, :integer, default_value: 5)
      resolve(dataloader(TdCx.Sources))
    end

    field :latest_event, :event, resolve: &Resolvers.Sources.latest_event/3

    field :jobs, list_of(:job) do
      arg(:limit, :integer, default_value: 20)
      resolve(dataloader(TdCx.Sources))
    end

    field :template, :template do
      resolve(&Resolvers.Sources.template/3)
    end
  end

  object :job do
    field :id, :id
    field :external_id, :string
    field :type, :string
    field :parameters, :json
    field :inserted_at, :datetime
    field :updated_at, :datetime

    field :events, list_of(:event) do
      arg(:limit, :integer, default_value: 20)
      resolve(dataloader(TdCx.Sources))
    end
  end

  object :event do
    field :id, :id
    field :type, :string
    field :message, :string
    field :inserted_at, :datetime
  end
end
