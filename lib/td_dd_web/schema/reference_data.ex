defmodule TdDdWeb.Schema.ReferenceData do
  @moduledoc """
  Absinthe schema definitions for reference datasets.
  """

  use Absinthe.Schema.Notation

  alias TdDdWeb.Resolvers

  object :reference_data_queries do
    @desc "Get a list of reference datasets"
    field :reference_datasets, list_of(:reference_dataset) do
      resolve(&Resolvers.ReferenceData.reference_datasets/3)
    end

    @desc "Get a reference dataset"
    field :reference_dataset, :reference_dataset do
      arg(:id, non_null(:id))
      resolve(&Resolvers.ReferenceData.reference_dataset/3)
    end
  end

  object :reference_data_mutations do
    @desc "Create a reference dataset"
    field :create_reference_dataset, :reference_dataset do
      arg(:dataset, non_null(:create_reference_dataset_input))
      resolve(&Resolvers.ReferenceData.create_reference_dataset/3)
      middleware(Crudry.Middlewares.TranslateErrors)
    end

    @desc "Update a reference dataset"
    field :update_reference_dataset, :reference_dataset do
      arg(:dataset, non_null(:update_reference_dataset_input))
      resolve(&Resolvers.ReferenceData.update_reference_dataset/3)
      middleware(Crudry.Middlewares.TranslateErrors)
    end

    @desc "Delete a reference dataset"
    field :delete_reference_dataset, :reference_dataset do
      arg(:id, non_null(:id))
      resolve(&Resolvers.ReferenceData.delete_reference_dataset/3)
      middleware(Crudry.Middlewares.TranslateErrors)
    end
  end

  object :reference_dataset do
    field :id, non_null(:id)
    field :name, :string
    field :headers, list_of(:string)
    field :rows, list_of(list_of(:string))
    field :row_count, :integer
    field :domains, list_of(:domain), resolve: &Resolvers.Domains.domains/3
    field :domain_ids, list_of(:integer)
    field :inserted_at, :datetime
    field :updated_at, :datetime
  end

  input_object :create_reference_dataset_input do
    field :name, non_null(:string)
    field :data, :data_url

    @desc "List of Domains"
    field :domain_ids, list_of(:id)
  end

  input_object :update_reference_dataset_input do
    field :id, non_null(:id)
    field :name, non_null(:string)
    field :data, :data_url

    @desc "List of Domains"
    field :domain_ids, list_of(:id)
  end
end
