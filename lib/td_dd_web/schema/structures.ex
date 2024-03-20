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

    @desc "Get a the latest data structure version"
    field :data_structure_version, :data_structure_version do
      arg(:data_structure_id, non_null(:id))
      arg(:version, non_null(:string))
      resolve(&Resolvers.Structures.data_structure_version/3)
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
    field(:id, non_null(:id))
    field(:confidential, non_null(:boolean))
    field(:domain_id, :integer, resolve: &Resolvers.Structures.domain_id/3)
    field(:domain_ids, list_of(:integer))
    field(:domains, list_of(:domain), resolve: &Resolvers.Domains.domains/3)
    field(:external_id, non_null(:string))
    field(:inserted_at, :datetime)
    field(:updated_at, :datetime)
    field(:system_id, :integer)
    field(:system, :system, resolve: dataloader(TdDd.DataStructures))
    field(:current_version, :data_structure_version, resolve: dataloader(TdDd.DataStructures))
    field(:units, list_of(:unit), resolve: dataloader(TdDd.DataStructures))
    field(:latest_note, :json)
    field(:alias, :string)
    field(:source_id, :integer)
    field(:source, :source)

    field(:structure_tags, list_of(:structure_tag),
      resolve: &Resolvers.Structures.structure_tags/3
    )

    field(:data_structure_links, list_of(:data_structure_link),
      resolve: &Resolvers.Structures.data_structure_links/3
    )

    field(:available_tags, list_of(:tag), resolve: &Resolvers.Structures.available_tags/3)

    field(:roles, list_of(:string), resolve: &Resolvers.Structures.roles/3)
  end

  object :data_structure_version do
    field(:id, non_null(:id))
    field(:alias, :string, resolve: &Resolvers.Structures.add_alias/3)
    field(:version, non_null(:integer))
    field(:class, :string)
    field(:description, :string)
    field(:name, :string)
    field(:type, :string)
    field(:group, :string)
    field(:deleted_at, :datetime)
    field(:inserted_at, :datetime)
    field(:updated_at, :datetime)
    field(:metadata, :json, resolve: &Resolvers.Structures.metadata/3)
    field(:data_structure_id, :id)
    field(:data_structure, :data_structure, resolve: dataloader(TdDd.DataStructures))
    field(:path, list_of(:string), resolve: &Resolvers.Structures.data_structure_version_path/3)

    field(:path_with_ids, list_of(:path_with_id),
      resolve: &Resolvers.Structures.data_structure_version_path_with_ids/3
    )

    field :parents, list_of(:data_structure_version) do
      arg(:deleted, :boolean, default_value: false)
      resolve(&Resolvers.Structures.parents/3)
    end

    field :children, list_of(:data_structure_version) do
      arg(:deleted, :boolean, default_value: false)
      resolve(&Resolvers.Structures.children/3)
    end

    field(:siblings, list_of(:data_structure_version))
    field(:versions, list_of(:data_structure_version))

    field :data_fields, list_of(:data_structure_version)

    field(:ancestry, list_of(:json), resolve: &Resolvers.Structures.ancestry/3)

    field(:relations, :relations, resolve: &Resolvers.Structures.relations/3)

    field(:classes, :json)
    field(:implementation_count, :integer)
    field(:data_structure_link_count, :integer)
    field(:degree, :graph_degree)

    field :note, :json do
      arg(:select_fields, list_of(:string))
      resolve(&Resolvers.Structures.note/3)
    end

    field(:profile, :profile, resolve: &Resolvers.Structures.profile/3)
    field(:source, :source)
    field(:system, :system)
    field(:structure_type, :data_structure_type, resolve: dataloader(TdDd.DataStructures))

    field(:grants, list_of(:grant))
    field(:grant, :grant)

    field(:links, list_of(:json), resolve: &Resolvers.Structures.links/3)
    field(:_actions, :json, resolve: &Resolvers.Structures.actions/3)
    field(:user_permissions, :json)
  end

  object :relations do
    field(:parents, list_of(:embedded_relation))
    field(:children, list_of(:embedded_relation))
  end

  object :path_with_id do
    field(:data_structure_id, non_null(:id))
    field(:name, :string)
  end

  object :graph_degree do
    field(:in, :integer)
    field(:out, :integer)
  end

  object :data_structure_relation do
    field(:id, non_null(:id))
    field(:parent_id, :id)
    field(:child_id, :id)
    field(:relation_type_id, :id)
    field(:relation_type, :relation_type, resolve: dataloader(TdDd.DataStructures))
    field(:inserted_at, :datetime)
    field(:updated_at, :datetime)
    field(:parent, :data_structure_version, resolve: dataloader(TdDd.DataStructures))
    field(:child, :data_structure_version, resolve: dataloader(TdDd.DataStructures))
  end

  object :embedded_relation do
    field(:id, non_null(:id))
    field(:relation_type, :relation_type)
    field(:structure, :data_structure_version)
    field(:links, list_of(:json))
  end

  object :data_structure_type do
    field(:name, :string)
    field(:template_id, :integer)
    field(:translation, :string)
    field(:filters, list_of(:string))
    field(:template, :json)
    field(:metadata_views, list_of(:metadata_view))
  end

  object :metadata_view do
    field(:name, :string)
    field(:fields, list_of(:string))
  end

  object :relation_type do
    field(:id, non_null(:id))
    field(:name, :string)
    field(:description, :string)
  end

  object :system do
    field(:id, non_null(:id))
    field(:external_id, non_null(:string))
    field(:name, non_null(:string))
    field(:df_content, :json)
    field(:inserted_at, :datetime)
    field(:updated_at, :datetime)
  end

  object :unit do
    field(:id, non_null(:id))
    field(:name, non_null(:string))
  end

  object :profile do
    field(:max, :string)
    field(:min, :string)
    field(:most_frequent, list_of(:json))
    field(:null_count, :integer)
    field(:patterns, list_of(:json))
    field(:total_count, :integer)
    field(:unique_count, :integer)
    field(:value, :json)
  end
end
