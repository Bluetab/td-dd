defmodule TdCx.Sources.Source do
  @moduledoc "Source entity"

  use Ecto.Schema
  import Ecto.Changeset

  schema "sources" do
    field :config, :map
    field :external_id, :string
    field :secrets_key, :string
    field :type, :string

    timestamps(type: :utc_datetime_usec)
  end

  @doc false
  def changeset(source, attrs) do
    source
    |> cast(attrs, [:external_id, :config, :secrets_key, :type])
    |> validate_required([:external_id, :type])
    |> validate_required_inclusion([:secrets_key, :config])
    |> unique_constraint(:external_id)
  end

  def validate_required_inclusion(changeset, fields) do
    if Enum.any?(fields, &present?(changeset, &1)) do
      changeset
    else
      add_error(changeset, hd(fields), "One of these fields must be present: #{inspect fields}")
    end
  end

  def present?(changeset, field) do
    # IO.puts "----present"
    # IO.inspect field
    # IO.inspect changeset
    value = get_field(changeset, field)
    # IO.inspect value
    value != nil && value != "" && value != %{}
  end
end
