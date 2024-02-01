defmodule TdDdWeb.Schema.Tags do
  @moduledoc """
  Absinthe schema definitions for tags.
  """

  use Absinthe.Schema.Notation

  alias TdDdWeb.Resolvers

  object :tag_queries do
    @desc "Get a list of tags"
    field :tags, list_of(:tag) do
      resolve(&Resolvers.Tags.tags/3)
    end

    @desc "Get a tag"
    field :tag, non_null(:tag) do
      arg(:id, :id)
      resolve(&Resolvers.Tags.tag/3)
    end
  end

  object :tag_mutations do
    @desc "Creates a new tag"
    field :create_tag, non_null(:tag) do
      arg(:tag, non_null(:tag_input))
      resolve(&Resolvers.Tags.create_tag/3)
    end

    @desc "Updates a tag"
    field :update_tag, non_null(:tag) do
      arg(:tag, non_null(:tag_input))
      resolve(&Resolvers.Tags.update_tag/3)
    end

    @desc "Deletes a tag"
    field :delete_tag, non_null(:tag) do
      arg(:id, non_null(:id))
      resolve(&Resolvers.Tags.delete_tag/3)
    end
  end

  input_object :tag_input do
    field :id, :id
    field :name, non_null(:string)
    field :description, :string
    field :domain_ids, list_of(:id)
  end

  object :tag do
    field :id, non_null(:id)
    field :name, :string
    field :description, :string
    field :domain_ids, list_of(:id)
    field :structure_count, :integer
  end
end
