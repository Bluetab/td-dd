defmodule TdDdWeb.Schema.Domains do
  @moduledoc """
  Absinthe schema definitions for domains.
  """

  use Absinthe.Schema.Notation

  object :domain do
    field :id, non_null(:id)
    field :external_id, :string
    field :name, :string
  end
end
