defmodule TdDdWeb.Schema.StructureTags do
  @moduledoc """
  Absinthe schema definitions for data structure tags and related entities.
  """

  use Absinthe.Schema.Notation

  alias TdDdWeb.Resolvers

  object :structure_tag_queries do
    @desc "Get a list of structure tags"
    field :structure_tags, list_of(:structure_tag) do
      resolve(&Resolvers.StructureTags.structure_tags/3)
    end

    @desc "Get a structure tag"
    field :structure_tag, non_null(:structure_tag) do
      arg(:id, :id)
      resolve(&Resolvers.StructureTags.structure_tag/3)
    end
  end

  object :structure_tag_mutations do
    @desc "Creates a new structure tag"
    field :create_structure_tag, non_null(:structure_tag) do
      arg(:structure_tag, non_null(:structure_tag_input))
      resolve(&Resolvers.StructureTags.create_structure_tag/3)
    end

    @desc "Updates a structure tag"
    field :update_structure_tag, non_null(:structure_tag) do
      arg(:structure_tag, non_null(:structure_tag_input))
      resolve(&Resolvers.StructureTags.update_structure_tag/3)
    end

    @desc "Deletes a structure tag"
    field :delete_structure_tag, non_null(:structure_tag) do
      arg(:id, non_null(:id))
      resolve(&Resolvers.StructureTags.delete_structure_tag/3)
    end
  end

  input_object :structure_tag_input do
    field :id, :id
    field :name, non_null(:string)
    field :description, :string
    field :domain_ids, list_of(:id)
  end

  object :structure_tag do
    field :id, non_null(:id)
    field :name, :string
    field :description, :string
    field :domain_ids, list_of(:id)
    field :structure_count, :integer
  end

  object :data_structure_id do
    field :id, non_null(:id)
  end
end
