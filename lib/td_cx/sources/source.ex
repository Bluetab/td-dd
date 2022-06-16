defmodule TdCx.Sources.Source do
  @moduledoc """
  Ecto Schema module for metadata sources.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias TdCx.Jobs.Job
  alias TdCx.Sources.Source
  alias TdDfLib.Validation

  @type t :: %__MODULE__{}

  schema "sources" do
    field :active, :boolean, default: true
    field :config, :map
    field :deleted_at, :utc_datetime
    field :external_id, :string
    field :secrets_key, :string
    field :type, :string

    has_many :jobs, Job
    has_many :events, through: [:jobs, :events]

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(source, attrs) do
    source
    |> cast(attrs, [:external_id, :config, :secrets_key, :type, :active, :deleted_at])
    |> validate_required([:external_id, :type])
    |> validate_required_inclusion([:secrets_key, :config])
    |> validate_change(:config, &Validation.validate_safe/2)
    |> unique_constraint(:external_id)
  end

  def delete_changeset(%Source{} = source) do
    source
    |> change()
    |> foreign_key_constraint(:jobs,
      name: :jobs_source_id_fkey,
      message: "source.delete.existing.jobs"
    )
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
