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

  object :reference_dataset do
    field :id, non_null(:id)
    field :name, :string
    field :headers, list_of(:string)
    field :rows, list_of(list_of(:string))
    field :row_count, :integer
    field :inserted_at, :datetime
    field :updated_at, :datetime
  end
end
