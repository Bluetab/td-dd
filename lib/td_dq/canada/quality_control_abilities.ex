defmodule TdDq.Canada.QualityControlAbilities do
  @moduledoc false
  alias TdDq.Accounts.User
  alias TdDq.Permissions

  @show_valid_resource_type "custom_validation"

  def can?(%User{} = _user, :index_quality_control, _business_concept_id), do: true

  def can?(%User{} = user, :manage_quality_control, business_concept_id) do
    Permissions.authorized?(user, :manage_quality_rule, business_concept_id)
  end

  def can?(:show, resource_type), do: resource_type == @show_valid_resource_type
end
