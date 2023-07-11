defmodule TdDd.DataStructures.CatalogViewConfigs.Policy do
  @moduledoc "Authorization rules for CatalogViewConfigs"

  def authorize(_action, %{role: role}, _params) when role in ["admin", "service"], do: true

  def authorize(_action, _claims, _params), do: false
end
