defmodule TdDq.Canada.QualityControlAbilities do
  @moduledoc false
  alias TdDq.Accounts.User
  alias TdDq.Permissions

  def can?(%User{} = user, :create_quality_control, business_concept_id) do
    Permissions.authorized?(user, :create_quality_rule, business_concept_id)
  end
end
