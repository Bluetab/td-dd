defmodule TdDdWeb.Schema.User do
  @moduledoc """
  Absinthe schema definitions for user.
  """
  use Absinthe.Schema.Notation

  object :user do
    field :id, :id
    field :email, :string
    field :full_name, :string
    field :user_name, :string
  end
end
