defmodule TdCx.Sources.Source do
  @moduledoc "Source entity"

  use Ecto.Schema
  import Ecto.Changeset

  alias TdCx.Sources.Jobs.Job
  alias TdCx.Sources.Source

  schema "sources" do
    field(:config, :map)
    field(:external_id, :string)
    field(:secrets_key, :string)
    field(:type, :string)
    field(:active, :boolean, default: true)
    has_many(:jobs, Job)

    timestamps(type: :utc_datetime_usec)
  end

  @doc false
  def changeset(source, attrs) do
    source
    |> cast(attrs, [:external_id, :config, :secrets_key, :type, :active])
    |> validate_required([:external_id, :type])
    |> validate_required_inclusion([:secrets_key, :config])
    |> unique_constraint(:external_id)
  end

  def delete_changeset(%Source{} = source) do
    source
    |> change()
    |> foreign_key_constraint(:jobs, name: :jobs_source_id_fkey, message: "source.delete.existing.jobs")
  end

  def validate_required_inclusion(changeset, fields) do
    if Enum.any?(fields, &present?(changeset, &1)) do
      changeset
    else
      add_error(changeset, hd(fields), "One of these fields must be present: [secrets, config]")
    end
  end

  def present?(changeset, field) do
    value = get_field(changeset, field)
    value != nil && value != "" && value != %{}
  end
end
