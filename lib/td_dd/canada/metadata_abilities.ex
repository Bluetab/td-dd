defmodule TdDd.Canada.MetadataAbilities do
  @moduledoc false
  alias TdDd.Auth.Claims
  alias TdDd.DataStructures.DataStructure
  alias TdDd.DataStructures.DataStructureVersion
  alias TdDd.Permissions

  # Admin accounts can do anything
  def can?(%Claims{role: "admin"}, _action, _resource), do: true

  # Service accounts can view protected metadata
  def can?(%Claims{role: "service"}, :view_protected_metadata, _any), do: true

  def can?(%Claims{} = claims, :view_protected_metadata, [DataStructure, DataStructureVersion]) do
    ## REVIEW TD-5082: It is not working, the domains must be verified
    Permissions.authorized?(claims, :view_protected_metadata)
  end
end
