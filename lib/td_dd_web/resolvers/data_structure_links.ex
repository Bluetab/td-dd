
defmodule TdDdWeb.Resolvers.DataStructureLinks do
  @moduledoc """
  Absinthe resolvers for data structure links and related entities
  """

  alias TdDd.DataStructures.DataStructureLinks

  def data_structure_link(_data_structure_link, %{source_id: source_id, target_id: target_id} = params, _resolution) do
    {:ok, DataStructureLinks.get_by(params)}
  end

  def data_structure_link(_data_structure_link, %{external_id: external_id} = params, _resolution) do
    {:ok, DataStructureLinks.all_by_external_id(external_id)}
  end

end
