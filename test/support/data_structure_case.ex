defmodule TdDd.DataStructureCase do
  @moduledoc """
  This module defines the setup for tests requiring
  data structure fixtures.

  You may define functions here to be used as helpers in
  your tests.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      use TdDd.DataCase

      setup _context do
        system = insert(:system, id: 1)
        {:ok, system: system}
      end

      def create_hierarchy(names) do
        dsvs =
          Enum.map(
            names,
            &insert(:data_structure_version,
              name: &1,
              data_structure: build(:data_structure, external_id: &1)
            )
          )

        dsvs
        |> Enum.chunk_every(2, 1, :discard)
        |> Enum.each(fn [parent, child] ->
          insert(:data_structure_relation, parent_id: parent.id, child_id: child.id)
        end)

        dsvs
      end
    end
  end
end
