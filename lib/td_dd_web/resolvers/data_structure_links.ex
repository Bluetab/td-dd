defmodule TdDdWeb.Resolvers.DataStructureLinks do
  @moduledoc """
  Absinthe resolvers for data structure links and related entities
  """

  alias TdDd.DataStructures.DataStructureLinks

  def data_structure_link(
        _data_structure_link,
        %{source_id: _source_id, target_id: _target_id} = params,
        _resolution
      ) do
    {:ok, DataStructureLinks.get_by(params)}
  end

  def data_structure_link(_data_structure_link, %{external_id: external_id}, _resolution) do
    {:ok, DataStructureLinks.all_by_external_id(external_id)}
  end

  def actions(dsl, _args, %{context: %{claims: claims}}) do
    {:ok,
     %{
       delete_struct_to_struct_link: Bodyguard.permit?(DataStructureLinks, :delete, claims, dsl)
     }}
  end
end
