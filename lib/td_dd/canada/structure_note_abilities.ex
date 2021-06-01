defmodule TdDd.Canada.StructureNoteAbilities do
  @moduledoc false
  alias TdDd.Auth.Claims

  def can?(%Claims{role: "admin"}, _action), do: true
  def can?(_claims, _action), do: false
end
