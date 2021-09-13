defmodule TdDdWeb.Resolvers.Rules do
  @moduledoc """
  Absinthe resolvers for rules and related entities
  """

  alias TdDq.Rules

  def rules(_parent, args, _resolution) do
    rules = Rules.list_rules(args, enrich: [:domain])
    {:ok, rules}
  end
end
