defmodule TdDdWeb.Schema.DataStructureLinks do
  @moduledoc """
  Absinthe schema definitions for structure links and related entities.
  """

  use Absinthe.Schema.Notation

  import Absinthe.Resolution.Helpers, only: [dataloader: 1]

  alias TdDdWeb.Resolvers

  object :data_structure_link_queries do
    @desc "Get a data structure link"
    field :data_structure_link, :data_structure_link do
      arg(:source_id, non_null(:id))
      arg(:target_id, non_null(:id))
      resolve(&Resolvers.DataStructureLinks.data_structure_link/3)
    end
  end

  object :data_structure_link do
    field :source_id, non_null(:id)
    field :target_id, non_null(:id)
    field :inserted_at, :date
    field :updated_at, :date
  end
end
