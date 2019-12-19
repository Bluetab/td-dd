defmodule TdCx.Sources.Source do
  @moduledoc "Source entity"

  use Ecto.Schema
  import Ecto.Changeset

  schema "sources" do
    field :config, {:array, :map}
    field :external_id, :string
    field :secrets_key, :string
    field :type, :string

    timestamps(type: :utc_datetime_usec)
  end

  @doc false
  def changeset(source, attrs) do
    source
    |> cast(attrs, [:external_id, :config, :secrets_key, :type])
    |> validate_required([:external_id, :config, :type])
    |> unique_constraint(:external_id)
  end
end
