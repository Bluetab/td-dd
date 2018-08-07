defmodule TdDq.Permissions.MockPermissionResolver do
  @moduledoc false

  def has_permission?(_jti, _permission, _business_concept, _business_concept_id), do: true
end
