defmodule TdDd.ReferenceData.Dataset do
  @moduledoc """
  Ecto Schema module for reference datasets.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{}

  schema "reference_datasets" do
    field(:name, :string)
    field(:headers, {:array, :string})
    field(:data, {:array, {:array, :string}}, virtual: true)
    field(:rows, {:array, {:array, :string}})
    field(:row_count, :integer, virtual: true)
    field(:domain_ids, {:array, :integer}, default: [])

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(%{} = params), do: changeset(%__MODULE__{}, params)

  def changeset(%__MODULE__{} = struct, %{} = params) do
    struct
    |> cast(params, [:name, :data, :domain_ids])
    |> update_change(:data, &remove_empty/1)
    |> validate_change(:data, &validate_data/2)
    |> maybe_split_headers()
    |> validate_required([:name, :headers, :rows])
    |> unique_domain_ids()
    |> unique_constraint(:name)
  end

  defp remove_empty(data) do
    Enum.reject(data, fn
      [] -> true
      [""] -> true
      _ -> false
    end)
  end

  defp validate_data(_, []), do: [data: "can't be empty"]

  defp validate_data(_, [_]), do: [data: "must have at least one row"]

  defp validate_data(_, data) do
    max_rows = Application.get_env(:td_dd, TdDd.ReferenceData)[:max_rows]
    max_cols = Application.get_env(:td_dd, TdDd.ReferenceData)[:max_cols]

    with {:rows, rows} when rows <= max_rows <- {:rows, length(data)},
         {:freq, freq} when map_size(freq) == 1 <- {:freq, Enum.frequencies_by(data, &length/1)},
         {:cols, [n]} when n <= max_cols <- {:cols, Map.keys(freq)} do
      []
    else
      {:rows, _} -> [data: "maximum #{max_rows} rows"]
      {:freq, _} -> [data: "inconsistent length"]
      {:cols, _} -> [data: "maximum #{max_cols} columns"]
    end
  end

  defp maybe_split_headers(%{valid?: false} = changeset), do: changeset

  defp maybe_split_headers(%{valid?: true} = changeset) do
    case fetch_change(changeset, :data) do
      {:ok, data} ->
        {[headers], rows} = Enum.split(data, 1)

        changeset
        |> put_change(:headers, headers)
        |> put_change(:rows, rows)
        |> put_change(:row_count, length(rows))

      :error ->
        changeset
    end
  end

  defp unique_domain_ids(changeset) do
    update_change(changeset, :domain_ids, fn domain_ids ->
      domain_ids
      |> Enum.sort()
      |> Enum.uniq()
    end)
  end
end
