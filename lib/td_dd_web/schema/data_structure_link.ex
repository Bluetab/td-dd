defmodule TdDdWeb.Schema.DataStructureLinks do
  @moduledoc """
  Absinthe schema definitions for structure links and related entities.
  """

  use Absinthe.Schema.Notation

  import Absinthe.Resolution.Helpers, only: [dataloader: 1]
  alias TdDdWeb.Resolvers

  object :data_structure_link do
    field :id, non_null(:id)
    field :source_id, non_null(:id)
    field :target_id, non_null(:id)
    field :source, :data_structure, resolve: dataloader(TdDd.DataStructures)
    field :target, :data_structure, resolve: dataloader(TdDd.DataStructures)
    field :inserted_at, :date
    field :updated_at, :date
    field :labels, list_of(:label)
    field :_actions, :json, resolve: &Resolvers.DataStructureLinks.actions/3
  end

  object :label do
    field :id, non_null(:id)
    field :name, :string
  end
end
