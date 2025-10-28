defmodule TdDq.Implementations.BulkUpdate.Policy do
  @moduledoc "Authorization rules for TdDq.Implementations.BulkUpdate"

  alias TdDq.Permissions

  @behaviour Bodyguard.Policy

  # Admin accounts can do anything with implementations
  def authorize(_action, %{role: "admin"}, _params), do: true

  def authorize(:auto_publish, %{} = claims, _params) do
    Permissions.authorized?(claims, :publish_implementation)
  end

  def authorize(:bulk_upload, %{} = claims, _params) do
    Permissions.authorized_any?(claims, [
      :manage_ruleless_implementations,
      :manage_quality_rule_implementations,
      :manage_raw_quality_rule_implementations
    ])
  end

  def authorize(:bulk_update, %{} = claims, _params) do
    Permissions.authorized_any?(claims, [
      :manage_ruleless_implementations,
      :manage_quality_rule_implementations,
      :manage_raw_quality_rule_implementations
    ])
  end

  def authorize(_action, _claims, _params), do: false
end
