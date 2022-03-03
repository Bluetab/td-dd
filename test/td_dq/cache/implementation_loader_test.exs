defmodule TdDd.Cache.ImplementationLoaderTest do
  use TdDd.DataCase

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

      on_exit(fn ->
        Enum.each([id], &ImplementationCache.delete/1)
      end)

      assert %{ok: 1} =
               [id]
               |> ImplementationLoader.cache_implementations()
               |> Enum.frequencies_by(&elem(&1, 0))

      string_date = ts
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
      %{id: id, rule: %{id: rule_id, name: rule_name}} = insert(:implementation)

      on_exit(fn ->
        Enum.each([id], &ImplementationCache.delete/1)
      end)

      assert %{ok: 1} =
               [id]
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
  end
end
