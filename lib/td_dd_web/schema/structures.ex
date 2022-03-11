defmodule TdDdWeb.Schema.Structures do
  @moduledoc """
  Absinthe schema definitions for data structures and related entities.
  """

  use Absinthe.Schema.Notation

  import Absinthe.Resolution.Helpers, only: [dataloader: 1]

  alias TdDdWeb.Resolvers

  object :structure_queries do
    @desc "Get a list of data structure versions"
    field :data_structure_versions, list_of(:data_structure_version) do
      arg(:since, :datetime)
      arg(:min_id, :integer)
      arg(:limit, :integer, default_value: 1_000)
      arg(:order_by, :string, default_value: "id")
      resolve(&Resolvers.Structures.data_structure_versions/3)
    end
  end

  object :data_structure_version do
    field :id, non_null(:id)
    field :version, non_null(:integer)
    field :class, :string
    field :description, :string
    field :type, :string
    field :group, :string
    field :deleted_at, :datetime
    field :inserted_at, :datetime
    field :updated_at, :datetime
    field :metadata, :json
    field :data_structure, :data_structure, resolve: dataloader(TdDd.DataStructures)
  end

  object :data_structure do
    field :id, non_null(:id)
    field :confidential, non_null(:boolean)
    field :domain_id, :integer, resolve: &Resolvers.Structures.domain_id/3
    field :domain_ids, list_of(:integer)
    field :external_id, non_null(:string)
    field :inserted_at, :datetime
    field :updated_at, :datetime
    field :system, :system, resolve: dataloader(TdDd.DataStructures)
  end

  object :system do
    field :id, non_null(:id)
    field :external_id, non_null(:string)
    field :name, non_null(:string)
    field :df_content, :json
    field :inserted_at, :datetime
    field :updated_at, :datetime
  end
end
