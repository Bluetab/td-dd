defmodule TdDd.Grants.GrantStructure do
  @moduledoc """
  Structure used for grant indexing, instead of TdDd.Grants.Grant, to allow
  multiple data structure version children per grant (each document has one
  grant and one data structure version child).
  """

  defstruct [:grant, :data_structure_version]
end
