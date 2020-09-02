defmodule TdCx.Configurations.Configuration do
  @moduledoc """
  Configuration Entity
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias TdDfLib.Validation

  schema "configurations" do
    field(:config, :map)
    field(:deleted_at, :utc_datetime_usec)
    field(:external_id, :string)
    field(:secrets_key, :string)
    field(:type, :string)

    timestamps()
  end

  @doc false
  def changeset(attrs) do
    changeset(%__MODULE__{}, attrs)
  end

  @doc false
  def changeset(configuration, attrs) do
    configuration
    |> cast(attrs, [:config, :external_id, :type, :deleted_at])
    |> validate_required([:external_id, :type])
    |> unique_constraint(:external_id)
    |> validate_template(configuration)
  end

  @doc false
  def update_changeset(configuration, attrs) do
    configuration
    |> cast(attrs, [:config, :deleted_at])
    |> validate_template(configuration)
  end

  def update_config(changeset, config) do
    put_change(changeset, :config, config)
  end

  def update_secrets_key(changeset, secrets_key) do
    put_change(changeset, :secrets_key, secrets_key)
  end

  defp validate_template(%Ecto.Changeset{valid?: true} = changeset, configuration) do
    validate_change(changeset, :config, Validation.validator(template_name(configuration, changeset)))
  end

  defp validate_template(changeset, _attrs), do: changeset

  defp template_name(_configuration, %{changes: %{type: type}}), do: type
  defp template_name(%{type: type}, _params), do: type
end
