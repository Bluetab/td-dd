defmodule TdDdWeb.Resolvers.DataStructureLinks do
  @moduledoc """
  Absinthe resolvers for data structure links and related entities
  """

  alias TdDd.DataStructures.DataStructureLinks

  def data_structure_link(_data_structure_link, %{source_id: source_id, target_id: target_id}, _resolution) do
    {:ok, DataStructureLinks.all_by(source_id: source_id, target_id: target_id)}
  end

end
