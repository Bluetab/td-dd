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
  def changeset(attrs, data_structure) do
    %__MODULE__{}
    |> cast(attrs, [:detail, :start_date, :end_date, :user_id])
    |> validate_required([:start_date, :user_id])
    |> put_assoc(:data_structure, data_structure)
    |> validate_required([:data_structure])
    |> validate_range()
  end

  @doc false
  def update_changeset(grant, attrs) do
    grant
    |> cast(attrs, [:detail, :start_date, :end_date])
    |> validate_required([:start_date])
    |> validate_range()
  end

  defp validate_range(%{valid?: true} = changeset) do
    end_date = get_field(changeset, :end_date)

    validate_change(changeset, :start_date, fn :start_date, start_date ->
      if is_nil(end_date) or end_date >= start_date do
        []
      else
        [start_date: "should be less than end_date"]
      end
    end)
  end

  defp validate_range(changeset), do: changeset
end
