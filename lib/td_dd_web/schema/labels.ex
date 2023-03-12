defmodule TdDdWeb.Schema.Labels do
  @moduledoc """
  Absinthe schema definitions for structure link labels.
  """

  use Absinthe.Schema.Notation

  alias TdDdWeb.Resolvers

  object :label_queries do
    @desc "Get a list of structure link labels"
    field :labels, list_of(:label) do
      resolve(&Resolvers.Labels.labels/3)
    end
  end

  object :label do
    field :id, non_null(:id)
    field :name, :string
  end
end
