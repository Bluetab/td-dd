defmodule TdCx.Sources.Source do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  schema "sources" do
    field :config, {:array, :map}
    field :external_id, :string
    field :secrets, {:array, :map}
    field :type, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(source, attrs) do
    source
    |> cast(attrs, [:type, :external_id, :secrets, :config])
    |> validate_required([:type, :external_id, :config])
    |> unique_constraint(:external_id)
  end
end
