defmodule TdDdWeb.Schema.Me do
  @moduledoc """
  Absinthe schema definitions for current user and related entities.
  """

  use Absinthe.Schema.Notation

  alias TdDdWeb.Resolvers

  object :me_queries do
    @desc "Get information about the current user"
    field :me, :me do
      resolve(&Resolvers.Me.me/3)
    end
  end

  object :me do
    field :id, non_null(:id)
    field :name, :string

    field :execution_groups_connection, :execution_groups_connection do
      arg(:first, :integer)
      arg(:last, :integer)
      arg(:after, :cursor)
      arg(:before, :cursor)
      resolve(&Resolvers.Executions.execution_groups_connection/3)
    end
  end
end
