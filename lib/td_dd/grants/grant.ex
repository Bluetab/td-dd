defmodule TdDd.Grants.Grant do
  @moduledoc """
  Ecto Schema module for Grant.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias TdDd.DataStructures.DataStructure

  schema "grants" do
    field(:detail, :map)
    field(:end_date, :utc_datetime_usec)
    field(:start_date, :utc_datetime_usec)
    field(:user_id, :integer)
    field(:data_structure_version, :map, virtual: true)
    field(:user, :map, virtual: true)

    belongs_to(:data_structure, DataStructure)

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(%__MODULE__{} = struct, %{} = params) do
    struct
    |> cast(params, [:detail, :start_date, :end_date])
    |> validate_required(:start_date)
    |> validate_range()
  end

  defp validate_range(%{valid?: true} = changeset) do
    end_date = get_field(changeset, :end_date)

    validate_change(changeset, :start_date, fn :start_date, start_date ->
      if is_nil(end_date) or DateTime.compare(end_date, start_date) != :lt do
        []
      else
        [start_date: "should be before end_date"]
      end
    end)
  end

  defp validate_range(changeset), do: changeset
end
