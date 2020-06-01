defmodule TdDd.DataStructureCase do
  @moduledoc """
  This module defines the setup for tests requiring
  data structure fixtures.

  You may define functions here to be used as helpers in
  your tests.
  """

  use ExUnit.CaseTemplate

  alias TdDd.DataStructures.RelationTypes

  using do
    quote do
      use TdDd.DataCase

      setup _context do
        system = insert(:system, id: 1)
        {:ok, system: system}
      end

      def create_hierarchy(names) do
        %{id: system_id} = insert(:system)

        dsvs =
          Enum.map(
            names,
            &insert(:data_structure_version,
              name: &1,
              data_structure: build(:data_structure, external_id: &1, system_id: system_id)
            )
          )

        %{id: relation_type_id} = RelationTypes.get_default()

        dsvs
        |> Enum.chunk_every(2, 1, :discard)
        |> Enum.each(fn [parent, child] ->
          insert(:data_structure_relation,
            parent_id: parent.id,
            child_id: child.id,
            relation_type_id: relation_type_id
          )
        end)

        dsvs
      end
    end
  end
end
