defmodule TdDdWeb.Schema.Templates do
  @moduledoc """
  Absinthe schema definitions for templates.
  """

  use Absinthe.Schema.Notation

  alias TdDdWeb.Resolvers

  object :template_queries do
    @desc "Get a list of templates"
    field :templates, list_of(:template) do
      arg(:scope, :string)
      arg(:domain_ids, list_of(:id))
      resolve(&Resolvers.Templates.templates/3)
    end

    @desc "Get a template by name"
    field :template, :template do
      arg(:name, non_null(:string))
      arg(:domain_ids, list_of(:id))
      resolve(&Resolvers.Templates.template/3)
    end
  end

  object :template do
    field :id, :id
    field :name, :string
    field :label, :string
    field :scope, :string
    field :content, :json
    field :updated_at, :datetime, resolve: &Resolvers.Templates.updated_at/3
  end
end
