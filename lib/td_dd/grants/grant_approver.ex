defmodule TdDd.Grants.GrantApprover do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset

  schema "grant_approvers" do
    field :name, :string
    timestamps(type: :utc_datetime_usec)
  end

  def changeset(%{} = params) do
    changeset(%__MODULE__{}, params)
  end

  def changeset(%__MODULE__{} = struct, %{} = params) do
    struct
    |> cast(params, [:name])
    |> validate_required(:name, message: "required")
    |> unique_constraint(:name, message: "unique")
  end
end
