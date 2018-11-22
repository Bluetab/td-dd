defmodule TdDd.Comments.Comment do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset
  alias TdDd.Comments.Comment

  schema "comments" do
    field :content, :string
    field :resource_id, :integer
    field :resource_type, :string
    field :user_id, :integer

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(%Comment{} = comment, attrs) do
    comment
    |> cast(attrs, [:resource_id, :resource_type, :user_id, :content])
    |> validate_required([:resource_id, :resource_type, :user_id, :content])
  end
end
