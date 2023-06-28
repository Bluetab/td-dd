defmodule TdDdWeb.Schema.CatalogViewConfigs do
  @moduledoc """
  Absinthe schema definitions for CatalogViewConfigs
  """
  use Absinthe.Schema.Notation

  alias TdDdWeb.Resolvers

  object :catalog_view_config_queries do
    @desc "Get list of grant catalog view configs"
    field :catalog_view_configs, list_of(:catalog_view_config) do
      resolve(&Resolvers.CatalogViewConfigs.catalog_view_configs/3)
    end

    @desc "Get catalog view config"
    field :catalog_view_config, :catalog_view_config do
      arg(:id, non_null(:id))
      resolve(&Resolvers.CatalogViewConfigs.catalog_view_config/3)
    end
  end

  object :catalog_view_config_mutations do
    @desc "Create new catalog view config"
    field :create_catalog_view_config, :catalog_view_config do
      arg(:catalog_view_config, non_null(:create_catalog_view_config_input))
      resolve(&Resolvers.CatalogViewConfigs.create_catalog_view_config/3)
      middleware(Crudry.Middlewares.TranslateErrors)
    end

    @desc "Update catalog view config"
    field :update_catalog_view_config, :catalog_view_config do
      arg(:catalog_view_config, non_null(:update_catalog_view_config_input))
      resolve(&Resolvers.CatalogViewConfigs.update_catalog_view_config/3)
      middleware(Crudry.Middlewares.TranslateErrors)
    end

    @desc "Delete a catalog view config"
    field :delete_catalog_view_config, :catalog_view_config do
      arg(:id, non_null(:id))
      resolve(&Resolvers.CatalogViewConfigs.delete_catalog_view_config/3)
      middleware(Crudry.Middlewares.TranslateErrors)
    end
  end

  object :catalog_view_config do
    field :id, non_null(:id)
    field :field_type, non_null(:string)
    field :field_name, non_null(:string)
  end

  input_object :create_catalog_view_config_input do
    field :field_name, non_null(:string)
    field :field_type, non_null(:string)
  end

  input_object :update_catalog_view_config_input do
    field :id, non_null(:id)
    field :field_name, :string
    field :field_type, :string
  end
end
