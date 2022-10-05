defmodule TdDdWeb.Schema.Functions do
  @moduledoc """
  Absinthe schema definitions for functions.
  """

  use Absinthe.Schema.Notation

  alias TdDdWeb.Resolvers

  object :function_queries do
    @desc "Get a list of functions"
    field :functions, list_of(:function) do
      resolve(&Resolvers.Functions.functions/3)
    end
  end

  object :function do
    field :id, non_null(:id)
    field :name, :string
    field :return_type, :string
    field :scope, :string
    field :group, :string
    field :args, list_of(:argument)
  end

  object :argument do
    field :type, :string
    field :name, :string
    field :values, list_of(:string)
  end
end
