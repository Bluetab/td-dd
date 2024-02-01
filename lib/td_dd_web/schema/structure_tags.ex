defmodule TdDdWeb.Schema.StructureTags do
  @moduledoc """
  Absinthe schema definitions for data structure tags
  """

  use Absinthe.Schema.Notation

  import Absinthe.Resolution.Helpers, only: [dataloader: 1]

  alias TdDdWeb.Resolvers

  object :structure_tag_mutations do
    @desc "Creates or replaces a structure tag"
    field :tag_structure, non_null(:structure_tag) do
      arg(:structure_tag, non_null(:structure_tag_input))
      resolve(&Resolvers.StructureTags.tag_structure/3)
      middleware(Crudry.Middlewares.TranslateErrors)
    end

    @desc "Deletes a structure tag"
    field :delete_structure_tag, non_null(:structure_tag) do
      arg(:id, non_null(:id))
      resolve(&Resolvers.StructureTags.delete_structure_tag/3)
      middleware(Crudry.Middlewares.TranslateErrors)
    end
  end

  input_object :structure_tag_input do
    field :id, :id
    field :data_structure_id, non_null(:id)
    field :tag_id, non_null(:id)
    field :inherit, non_null(:boolean), default_value: false
    field :comment, :string
  end

  object :structure_tag do
    field :id, non_null(:id)
    field :inherit, non_null(:boolean)
    field :inherited, :boolean
    field :comment, :string
    field :data_structure, :data_structure, resolve: dataloader(TdDd.DataStructures)
    field :data_structure_id, :id
    field :tag, :tag, resolve: dataloader(TdDd.DataStructures)
    field :tag_id, :id
    field :inserted_at, :datetime
    field :updated_at, :datetime
  end
end
