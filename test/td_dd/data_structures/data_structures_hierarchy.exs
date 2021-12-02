defmodule TdDd.DataStructures.Hierarchy do
  use TdDd.DataStructureCase

  import TdDd.TestOperators

  @moduletag sandbox: :shared

  setup do
    domain = CacheHelpers.insert_domain()
    %{id: system_id} = system = insert(:system, external_id: "test_system")

    start_supervised!(TdDd.Search.StructureEnricher)

    [
      domain: domain,
      system: system,
    ]
  end

  describe "TEST" do
    test "test cosas", %{} do
      data_structure_versions = create_hierarchy(["A", "B", "C"])

      data_structure_versions
      |> Enum.map(&(&1.name))
      |> IO.inspect

    end
  end

end
