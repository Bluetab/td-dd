defmodule TdDd.Grants.GrantApprover do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  schema "grant_approvers" do
    field :name, :string

    timestamps()
  end

  @doc false
  def changeset(grant_approver, attrs) do
    grant_approver
    |> cast(attrs, [:name])
    |> validate_required([:name], message: "required")
    |> unique_constraint(:name, message: "required")
  end
end
