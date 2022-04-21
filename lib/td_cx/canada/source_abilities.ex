defmodule TdCx.Canada.SourceAbilities do
  @moduledoc """
  Canada permissions model for Sources
  """
  alias TdCx.Permissions
  alias TdCx.Sources.Source

  def can?(%{:__struct__ => type, role: "user"} = claims, :list, Source)
      when type in [TdCx.Auth.Claims, TdDd.Auth.Claims] do
    Permissions.has_permission?(claims, :manage_raw_quality_rule_implementations)
  end
end
