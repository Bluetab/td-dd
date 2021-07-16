defmodule TdDd.Grants.Grant do
  @moduledoc """
  Ecto Schema module for Grant.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias TdDd.DataStructures.DataStructure

  schema "grants" do
    field :detail, :map
    field :end_date, :utc_datetime_usec
    field :start_date, :utc_datetime_usec
    field :user_id, :integer

    belongs_to(:data_structure, DataStructure)

    timestamps()
  end

  @doc false
  def changeset(grant, attrs, data_structure) do
    grant
    |> cast(attrs, [:detail, :start_date, :end_date, :user_id])
    |> validate_required([:detail, :start_date, :end_date, :user_id])
    |> put_assoc(:data_structure, data_structure)
    |> validate_required([:data_structure])
  end

  @doc false
  def update_changeset(grant, attrs) do
    grant
    |> cast(attrs, [:detail, :start_date, :end_date])
    |> validate_required([:detail, :start_date, :end_date])
  end
end
