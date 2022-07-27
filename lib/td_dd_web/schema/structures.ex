defmodule TdDdWeb.Schema.Structures do
  @moduledoc """
  Absinthe schema definitions for data structures and related entities.
  """

  use Absinthe.Schema.Notation

  import Absinthe.Resolution.Helpers, only: [dataloader: 1]

  alias TdDdWeb.Resolvers

  object :structure_queries do
    @desc "Get a list of data structures"
    field :data_structures, list_of(:data_structure) do
      arg(:since, :datetime)
      arg(:min_id, :integer)
      arg(:lineage, :boolean)
      arg(:limit, :integer, default_value: 1_000)
      arg(:order_by, :string, default_value: "id")
      arg(:external_id, list_of(:string))
      arg(:deleted, :boolean, default_value: false)
      resolve(&Resolvers.Structures.data_structures/3)
    end

    @desc "Get a data structure"
    field :data_structure, :data_structure do
      arg(:id, non_null(:id))
      resolve(&Resolvers.Structures.data_structure/3)
    end

    @desc "Get a list of data structure versions"
    field :data_structure_versions, list_of(:data_structure_version) do
      arg(:since, :datetime)
      arg(:min_id, :integer)
      arg(:limit, :integer, default_value: 1_000)
      arg(:order_by, :string, default_value: "id")
      resolve(&Resolvers.Structures.data_structure_versions/3)
    end

    @desc "Get a list of data structure relations"
    field :data_structure_relations, list_of(:data_structure_relation) do
      arg(:types, list_of(:string))
      arg(:since, :datetime)
      arg(:min_id, :integer)
      arg(:limit, :integer, default_value: 1_000)
      arg(:order_by, :string, default_value: "id")
      resolve(&Resolvers.Structures.data_structure_relations/3)
    end
  end

  object :data_structure do
    field :id, non_null(:id)
    field :confidential, non_null(:boolean)
    field :domain_id, :integer, resolve: &Resolvers.Structures.domain_id/3
    field :domain_ids, list_of(:integer)
    field :domains, list_of(:domain), resolve: &Resolvers.Structures.domains/3
    field :external_id, non_null(:string)
    field :inserted_at, :datetime
    field :updated_at, :datetime
    field :system, :system, resolve: dataloader(TdDd.DataStructures)
    field :current_version, :data_structure_version, resolve: dataloader(TdDd.DataStructures)
    field :units, list_of(:unit), resolve: dataloader(TdDd.DataStructures)

    field :structure_tags, list_of(:structure_tag),
      resolve: &Resolvers.Structures.structure_tags/3

    field :available_tags, list_of(:tag), resolve: &Resolvers.Structures.available_tags/3
  end

  object :data_structure_version do
    field :id, non_null(:id)
    field :version, non_null(:integer)
    field :class, :string
    field :description, :string
    field :name, :string
    field :type, :string
    field :group, :string
    field :deleted_at, :datetime
    field :inserted_at, :datetime
    field :updated_at, :datetime
    field :metadata, :json
    field :data_structure, :data_structure, resolve: dataloader(TdDd.DataStructures)
    field :path, list_of(:string), resolve: &Resolvers.Structures.data_structure_version_path/3

    field :parents, list_of(:data_structure_version) do
      arg(:deleted, :boolean, default_value: false)
      resolve(dataloader(TdDd.DataStructures))
    end
  end

  object :data_structure_relation do
    field :id, non_null(:id)
    field :parent_id, :id
    field :child_id, :id
    field :relation_type_id, :id
    field :relation_type, :relation_type, resolve: dataloader(TdDd.DataStructures)
    field :inserted_at, :datetime
    field :updated_at, :datetime
    field :parent, :data_structure_version, resolve: dataloader(TdDd.DataStructures)
    field :child, :data_structure_version, resolve: dataloader(TdDd.DataStructures)
  end

  object :relation_type do
    field :id, non_null(:id)
    field :name, :string
  end

  object :system do
    field :id, non_null(:id)
    field :external_id, non_null(:string)
    field :name, non_null(:string)
    field :df_content, :json
    field :inserted_at, :datetime
    field :updated_at, :datetime
  end

  object :unit do
    field(:id, non_null(:id))
    field(:name, non_null(:string))
  end
end
