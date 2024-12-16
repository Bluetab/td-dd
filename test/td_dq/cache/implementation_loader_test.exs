defmodule TdDd.Cache.ImplementationLoaderTest do
  use TdDd.DataCase

  import TdDd.TestOperators

  alias TdCache.ImplementationCache
  alias TdDq.Cache.ImplementationLoader

  describe "ImplementationLoader.cache_implementations/2" do
    setup do
      start_supervised!(TdDd.Search.StructureEnricher)
      :ok
    end

    @tag sandbox: :shared
    test "encodes and puts cache entries with rule_results" do
      %{id: id} = implementation = insert(:implementation)
      ts = DateTime.utc_now()
      insert(:rule_result, implementation: implementation, date: DateTime.add(ts, -10))

      %{
        errors: errors,
        records: records,
        result: expected_result
      } =
        insert(:rule_result,
          implementation: implementation,
          date: ts,
          errors: 6,
          records: 6,
          result: 100.00
        )

      assert %{ok: 1} =
               [id]
               |> ImplementationLoader.cache_implementations()
               |> Enum.frequencies_by(&elem(&1, 0))

      string_date =
        ts
        |> DateTime.truncate(:second)
        |> DateTime.to_string()

      assert {:ok,
              %{
                execution_result_info: %{
                  errors: ^errors,
                  records: ^records,
                  result: result,
                  date: ^string_date,
                  result_text: "quality_result.over_goal"
                }
              }} = ImplementationCache.get(id)

      assert Decimal.eq?(expected_result, result)
    end

    @tag sandbox: :shared
    test "encodes and puts cache entries with rule" do
      %{id: id, implementation_ref: implementation_ref, rule: %{id: rule_id, name: rule_name}} =
        insert(:implementation)

      assert %{ok: 1} =
               [implementation_ref]
               |> ImplementationLoader.cache_implementations()
               |> Enum.frequencies_by(&elem(&1, 0))

      assert {:ok,
              %{
                rule: %{
                  id: ^rule_id,
                  name: ^rule_name
                }
              }} = ImplementationCache.get(id)
    end

    @tag sandbox: :shared
    test "add relations between implementation_id and implementation_ref" do
      %{id: impl_id1} = impl1 = insert(:implementation)
      %{id: impl_id2} = impl2 = insert(:implementation)
      %{id: impl_id3} = impl3 = insert(:implementation, implementation_ref: impl_id2)
      %{id: impl_id4} = impl4 = insert(:implementation)
      impl5 = insert(:implementation, implementation_ref: impl_id4)

      [impl1, impl2, impl3, impl4, impl5]
      |> Enum.map(&CacheHelpers.put_implementation(&1))

      [impl_id1, impl_id3, impl_id4]
      |> Enum.map(&CacheHelpers.insert_link(&1, "implementation", "foo", nil))

      assert 3 == ImplementationLoader.do_migration_implementation_id_to_implementation_ref()

      result =
        ImplementationCache.get_relation_impl_id_and_impl_ref()
        |> Enum.map(&String.to_integer(&1))

      assert [impl_id1, impl_id1, impl_id3, impl_id2, impl_id4, impl_id4] ||| result
    end
  end
end
