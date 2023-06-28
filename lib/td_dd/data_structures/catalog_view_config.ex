defmodule TdDd.DataStructures.CatalogViewConfig do
  @moduledoc """
  Ecto Schema module for Catalog View Configs
  """
  use Ecto.Schema

  import Ecto.Changeset

  schema "catalog_view_configs" do
    field :field_type, :string
    field :field_name, :string

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(%{} = params) do
    changeset(%__MODULE__{}, params)
  end

  def changeset(%__MODULE__{} = struct, %{} = params) do
    struct
    |> cast(params, [:field_type, :field_name])
    |> validate_required([:field_type, :field_name])
    |> validate_inclusion(:field_type, ["metadata", "note"])
  end
end
