defmodule TdCx.Configurations.Configuration do
  @moduledoc """
  Configuration Entity
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias TdDfLib.Validation

  schema "configurations" do
    field(:content, :map)
    field(:external_id, :string)
    field(:secrets_key, :string)
    field(:type, :string)

    timestamps()
  end

  def changeset(attrs) do
    changeset(%__MODULE__{}, attrs)
  end

  def changeset(configuration, attrs) do
    configuration
    |> cast(attrs, [:content, :external_id, :type])
    |> validate_required([:external_id, :type])
    |> unique_constraint(:external_id)
    |> validate_template(configuration)
    |> validate_change(:content, &Validation.validate_safe/2)
  end

  def update_changeset(configuration, attrs) do
    configuration
    |> cast(attrs, [:content, :type])
    |> validate_template(configuration)
  end

  def update_config(changeset, content) do
    put_change(changeset, :content, content)
  end

  def update_secrets_key(changeset, secrets_key) do
    put_change(changeset, :secrets_key, secrets_key)
  end

  defp validate_template(%Ecto.Changeset{valid?: true} = changeset, configuration) do
    validate_change(
      changeset,
      :content,
      Validation.validator(template_name(configuration, changeset))
    )
  end

  defp validate_template(changeset, _attrs), do: changeset

  defp template_name(_configuration, %{changes: %{type: type}}), do: type
  defp template_name(%{type: type}, _params), do: type
end
