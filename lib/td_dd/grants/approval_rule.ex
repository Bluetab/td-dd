defmodule TdDd.Grants.ApprovalRule do
  @moduledoc """
  Ecto Schema module for Grant Request Approval rules
  """
  use Ecto.Schema

  import Ecto.Changeset

  alias TdCache.TaxonomyCache
  alias TdDd.Grants.Condition

  @valid_actions ["approve", "reject"]

  schema "approval_rules" do
    field :name, :string
    field :user_id, :integer
    field :domain_ids, {:array, :integer}
    field :role, :string
    field :action, :string
    field :comment, :string

    embeds_many :conditions, Condition, on_replace: :delete

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(%{} = attrs) do
    changeset(%__MODULE__{}, attrs)
  end

  def changeset(%__MODULE__{} = struct, %{} = attrs, claims \\ nil) do
    struct
    |> cast(attrs, [:comment, :role, :action, :domain_ids, :name])
    |> validate_required([
      :name,
      :user_id,
      :domain_ids,
      :role,
      :action
    ])
    |> validate_inclusion(:action, @valid_actions)
    |> cast_embed(:conditions, with: &Condition.changeset/2, required: true)
    |> validate_approver(claims)
  end

  defp validate_approver(%{valid?: false} = changeset, _), do: changeset

  defp validate_approver(changeset, %{role: "admin"}), do: changeset

  defp validate_approver(changeset, _) do
    with domain_ids <- fetch_field!(changeset, :domain_ids),
         user_id <- fetch_field!(changeset, :user_id),
         role <- fetch_field!(changeset, :role),
         true <- TaxonomyCache.has_role?(domain_ids, role, user_id) do
      changeset
    else
      _ -> add_error(changeset, :user_id, "invalid role")
    end
  end
end
