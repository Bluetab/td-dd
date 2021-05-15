defmodule TdDq.ImplementationsTest do
  use TdDd.DataCase

  import TdDd.TestOperators

  alias Ecto.Changeset
  alias TdDq.Implementations
  alias TdDq.Implementations.Implementation

  @moduletag sandbox: :shared

  setup do
    start_supervised!(TdDq.MockRelationCache)
    start_supervised!(TdDd.Search.MockIndexWorker)
    start_supervised!(TdDq.Cache.RuleLoader)
    start_supervised!(TdDd.Search.StructureEnricher)
    [rule: insert(:rule)]
  end

  describe "next_key/0" do
    test "returns automatically generated implementation key" do
      assert "ri0001" == Implementations.next_key()
      insert(:implementation, implementation_key: "ri0123")
      assert "ri0124" == Implementations.next_key()
    end
  end

  describe "list_implementations/0" do
    test "returns all implementations" do
      implementation = insert(:implementation)

      assert Implementations.list_implementations() <|> [implementation]
    end
  end

  describe "list_implementations/1" do
    test "returns all implementations by rule", %{rule: rule} do
      insert(:implementation, implementation_key: "ri1", rule: rule)
      insert(:implementation, implementation_key: "ri2", rule: rule)
      insert(:implementation, implementation_key: "ri3", rule: rule)
      insert(:raw_implementation, implementation_key: "ri5", rule: rule)

      assert length(Implementations.list_implementations(%{rule_id: rule.id})) == 4
    end

    test "returns non deleted implementations by rule", %{rule: rule1} do
      rule2 = insert(:rule, name: "#{rule1.name} 1")
      insert(:implementation, implementation_key: "ri1", rule: rule1)
      insert(:implementation, implementation_key: "ri2", rule: rule1)
      insert(:implementation, implementation_key: "ri3", rule: rule1)
      insert(:implementation, implementation_key: "ri4", rule: rule2)
      insert(:raw_implementation, implementation_key: "ri5", rule: rule2)

      insert(:implementation,
        implementation_key: "ri6",
        rule: rule2,
        deleted_at: DateTime.utc_now()
      )

      assert length(Implementations.list_implementations(%{rule_id: rule1.id})) == 3
      assert length(Implementations.list_implementations(%{rule_id: rule2.id})) == 2
    end

    test "returns all implementations by business_concept_id" do
      rule = insert(:rule, business_concept_id: "xyz")

      insert(:implementation, implementation_key: "ri1", rule: rule)
      insert(:implementation, implementation_key: "ri2", rule: rule)
      insert(:implementation, implementation_key: "ri3", rule: rule)

      assert length(
               Implementations.list_implementations(%{
                 rule: %{business_concept_id: "xyz"}
               })
             ) == 3
    end

    test "returns all implementations by status" do
      rule = insert(:rule, active: true)

      insert(:implementation, implementation_key: "ri1", rule: rule)
      insert(:implementation, implementation_key: "ri2", rule: rule)
      insert(:implementation, implementation_key: "ri3", rule: rule)

      assert length(Implementations.list_implementations(%{rule: %{active: true}})) == 3
    end

    test "returns deleted implementations when opts provided" do
      rule = insert(:rule, active: true)

      insert(:implementation,
        implementation_key: "ri1",
        rule: rule,
        deleted_at: DateTime.utc_now()
      )

      insert(:implementation, implementation_key: "ri2", rule: rule)
      insert(:implementation, implementation_key: "ri3", rule: rule)

      results = Implementations.list_implementations(%{"rule_id" => rule.id}, deleted: true)

      assert length(results) == 1

      assert Enum.any?(results, fn %{implementation_key: implementation_key} ->
               implementation_key == "ri1"
             end)
    end

    test "returns all implementations by structure", %{rule: rule} do
      %{structure: %{id: structure_id}} =
        dataset_row = build(:dataset_row, structure: build(:dataset_structure))

      %{structure: %{id: structure_id_2}} = validation_row = build(:condition_row)

      insert(:implementation,
        rule: rule,
        implementation_key: "ri11",
        dataset: [dataset_row],
        validations: [validation_row]
      )

      insert(:implementation,
        rule: rule,
        implementation_key: "ri12",
        dataset: [dataset_row],
        validations: [validation_row]
      )

      assert length(Implementations.list_implementations(%{"structure_id" => structure_id})) ==
               2

      assert length(Implementations.list_implementations(%{"structure_id" => structure_id_2})) ==
               2
    end

    test "preloads rule" do
      %{rule_id: rule_id} = insert(:implementation)
      assert [%{rule: rule}] = Implementations.list_implementations(%{}, preload: :rule)
      assert %{id: ^rule_id} = rule
    end

    test "enriches source" do
      %{id: source_id} = source = insert(:source)
      insert(:raw_implementation, raw_content: build(:raw_content, source_id: source_id))

      assert [%{raw_content: content}] =
               Implementations.list_implementations(%{}, enrich: :source)

      assert %{source: ^source} = content
    end
  end

  describe "get_implementation!/1" do
    test "returns the implementation with given id" do
      %{id: id} = implementation = insert(:implementation)
      assert Implementations.get_implementation!(id) <~> implementation
    end

    test "returns the implementation with given id even if it is soft deleted" do
      implementation = insert(:implementation, deleted_at: DateTime.utc_now())

      assert Implementations.get_implementation!(implementation.id)
             <~> implementation
    end

    test "preloads the rule" do
      %{id: id, rule_id: rule_id} = insert(:implementation)
      assert %{rule: rule} = Implementations.get_implementation!(id, preload: :rule)
      assert %{id: ^rule_id} = rule
    end

    test "enriches source" do
      %{id: source_id} = source = insert(:source)

      %{id: id} =
        insert(:raw_implementation, raw_content: build(:raw_content, source_id: source_id))

      assert %{raw_content: content} = Implementations.get_implementation!(id, enrich: :source)
      assert %{source: ^source} = content
    end
  end

  describe "get_implementation_by_key/1" do
    test "returns the implementation with given implementation key" do
      %{implementation_key: implementation_key} =
        implementation = insert(:implementation, implementation_key: "My implementation key")

      assert Implementations.get_implementation_by_key!(implementation_key)
             <~> implementation
    end

    test "raises if the implementation with given implementation key has been soft deleted" do
      %{implementation_key: implementation_key} =
        insert(:implementation,
          implementation_key: "My implementation key",
          deleted_at: DateTime.utc_now()
        )

      assert_raise Ecto.NoResultsError, fn ->
        Implementations.get_implementation_by_key!(implementation_key)
      end
    end
  end

  describe "create_implementation/2" do
    test "with valid data creates a implementation", %{rule: rule} do
      params = string_params_for(:implementation, rule_id: rule.id)

      assert {:ok, %Implementation{} = implementation} =
               Implementations.create_implementation(rule, params)

      assert implementation.rule_id == params["rule_id"]
    end

    test "with duplicated implementation key returns an error", %{rule: rule} do
      impl = insert(:implementation)

      params =
        string_params_for(:implementation,
          rule_id: rule.id,
          implementation_key: impl.implementation_key
        )

      assert {:error, %{valid?: false, errors: [implementation_key: {"duplicated", _}]}} =
               Implementations.create_implementation(rule, params)
    end

    test "with invalid keywords in raw content of raw implementation returns error", %{rule: rule} do
      raw_content = build(:raw_content, validations: "drop cliente")
      params = string_params_for(:raw_implementation, raw_content: raw_content)

      assert {:error, %Changeset{valid?: false} = changeset} =
               Implementations.create_implementation(rule, params)

      assert %{
               raw_content: %{
                 validations: [{"invalid.validations", [validation: :invalid_content]}]
               }
             } = Changeset.traverse_errors(changeset, & &1)
    end

    test "with valid data for raw implementation creates a implementation", %{rule: rule} do
      %{id: rule_id} = rule

      params = string_params_for(:raw_implementation, rule_id: rule_id)

      assert {:ok, %Implementation{} = implementation} =
               Implementations.create_implementation(rule, params)

      assert %{rule_id: ^rule_id} = implementation
    end

    test "with valid data with single structure creates a implementation", %{rule: rule} do
      params =
        string_params_for(:implementation, dataset: [build(:dataset_row)], rule_id: rule.id)

      assert {:ok, %Implementation{} = implementation} =
               Implementations.create_implementation(rule, params)

      assert implementation.rule_id == params["rule_id"]
    end

    test "with valid data with timestamp creates a implementation", %{rule: rule} do
      operator = build(:operator, name: "timestamp_gt_timestamp", value_type: "timestamp")

      validation =
        build(:condition_row, value: [%{raw: "2019-12-02 05:35:00"}], operator: operator)

      params = string_params_for(:implementation, validations: [validation], rule_id: rule.id)

      assert {:ok, %Implementation{} = implementation} =
               Implementations.create_implementation(rule, params)

      assert implementation.rule_id == params["rule_id"]
    end
  end

  describe "update_implementation/3" do
    test "with valid data updates the implementation" do
      implementation = insert(:implementation)
      claims = build(:dq_claims)

      validations = [
        %{
          operator: %{
            name: "gt",
            value_type: "timestamp"
          },
          structure: %{id: 12_554},
          value: [%{raw: "2019-12-30 05:35:00"}]
        }
      ]

      update_attrs =
        %{
          validations: validations
        }
        |> Map.Helpers.stringify_keys()

      assert {:ok, %{implementation: updated_implementation}} =
               Implementations.update_implementation(implementation, update_attrs, claims)

      assert %Implementation{} = updated_implementation
      assert updated_implementation.rule_id == implementation.rule_id

      assert updated_implementation.implementation_key ==
               implementation.implementation_key

      assert updated_implementation.validations == [
               %TdDq.Implementations.ConditionRow{
                 operator: %TdDq.Implementations.Operator{
                   name: "gt",
                   value_type: "timestamp"
                 },
                 structure: %TdDq.Implementations.Structure{id: 12_554},
                 value: [%{"raw" => "2019-12-30 05:35:00"}]
               }
             ]
    end

    test "with invalid data returns error changeset" do
      implementation = insert(:implementation)
      claims = build(:dq_claims)
      udpate_attrs = Map.put(%{}, :dataset, nil)

      assert {:error, :implementation, %Changeset{}, _} =
               Implementations.update_implementation(implementation, udpate_attrs, claims)
    end
  end

  describe "delete_implementation/1" do
    test "deletes the implementation" do
      implementation = insert(:implementation)

      assert {:ok, %Implementation{__meta__: meta}} =
               Implementations.delete_implementation(implementation)

      assert %{state: :deleted} = meta
    end

    test "deletes the implementation linked to executions" do
      %{id: id} = insert(:execution_group)
      implementation = %{id: implementation_id} = insert(:implementation)

      %{id: execution_id} =
        insert(:execution,
          group_id: id,
          implementation_id: implementation_id,
          result: insert(:rule_result)
        )

      assert {:ok, %Implementation{__meta__: meta}} =
               Implementations.delete_implementation(implementation)

      assert %{state: :deleted} = meta
      assert is_nil(Repo.get(TdDq.Executions.Execution, execution_id))
    end
  end

  describe "get_structure_ids/1" do
    test "returns ids of all structures present in implementation", %{rule: rule} do
      creation_attrs = %{
        dataset: [
          %{structure: %{id: 1}},
          %{clauses: [%{left: %{id: 2}, right: %{id: 3}}], structure: %{id: 4}},
          %{clauses: nil, structure: %{id: 5}}
        ],
        population: [
          %{
            operator: %{
              name: "timestamp_gt_timestamp",
              value_type: "timestamp"
            },
            structure: %{id: 6},
            value: [%{raw: "2019-12-02 05:35:00"}]
          }
        ],
        validations: [
          %{
            operator: %{
              name: "timestamp_gt_timestamp",
              value_type: "timestamp",
              value_type_filter: "timestamp"
            },
            structure: %{id: 7},
            value: [%{raw: "2019-12-02 05:35:00"}]
          },
          %{
            operator: %{
              name: "not_empty"
            },
            structure: %{id: 8},
            value: nil
          }
        ]
      }

      implementation_key = "rik1"

      rule_implementaton =
        insert(:implementation,
          implementation_key: implementation_key,
          rule: rule,
          dataset: creation_attrs.dataset,
          population: creation_attrs.population,
          validations: creation_attrs.validations
        )

      structures_ids = Implementations.get_structure_ids(rule_implementaton)

      assert Enum.sort(structures_ids) == [1, 2, 3, 4, 5, 6, 7, 8]
    end
  end

  describe "get_rule_implementations/1" do
    test "returns all implementations of a set of rules" do
      r = insert(:rule)
      r1 = insert(:rule)

      ri = insert(:implementation, rule: r)
      ri1 = insert(:implementation, rule: r1)
      ids = [ri.id, ri1.id]

      assert Implementations.get_rule_implementations([]) == []
      assert [_ | _] = implementations = Implementations.get_rule_implementations([r.id, r1.id])
      Enum.all?(implementations, &(&1.id in ids))
    end
  end

  describe "deprecate/1" do
    test "logically deletes implementations" do
      deleted_at = DateTime.utc_now()
      %{id: id1} = insert(:implementation, rule: build(:rule))
      %{id: id2} = insert(:implementation, rule: build(:rule), deleted_at: deleted_at)
      %{id: id3} = insert(:implementation, rule: build(:rule))

      assert {:ok, %{deprecated: deprecated}} = Implementations.deprecate([id1, id2, id3])
      assert {2, [%{id: ^id1}, %{id: ^id3}]} = deprecated
    end

    test "publishes audit events" do
      deleted_at = DateTime.utc_now()
      %{id: id1} = insert(:implementation, rule: build(:rule))
      %{id: id2} = insert(:implementation, rule: build(:rule), deleted_at: deleted_at)
      %{id: id3} = insert(:implementation, rule: build(:rule))

      assert {:ok, %{audit: audit}} = Implementations.deprecate([id1, id2, id3])
      assert length(audit) == 2
    end
  end

  describe "deprecate_implementations/1" do
    test "deprecates implementations which don't reference existing structure ids" do
      %{data_structure_id: structure_id1} = insert(:data_structure_version)

      %{data_structure_id: structure_id2} =
        insert(:data_structure_version, deleted_at: DateTime.utc_now())

      insert(:implementation,
        dataset: [build(:dataset_row, structure: build(:dataset_structure, id: structure_id1))],
        population: [],
        validations: []
      )

      assert :ok = Implementations.deprecate_implementations()

      %{id: id2} =
        insert(:implementation,
          dataset: [build(:dataset_row, structure: build(:dataset_structure, id: structure_id2))],
          population: [],
          validations: []
        )

      %{id: id3} = insert(:implementation)

      assert {:ok, %{deprecated: deprecated}} = Implementations.deprecate_implementations()
      assert {2, implementations} = deprecated
      assert ids = Enum.map(implementations, & &1.id)
      assert id2 in ids
      assert id3 in ids
    end
  end

  describe "get_sources/1" do
    setup do
      %{id: sid1} = source1 = insert(:source, config: %{"alias" => "foo"})
      %{id: sid2} = source2 = insert(:source, config: %{"aliases" => ["bar", "baz"]})

      %{data_structure_id: structure_id1, data_structure: s1} =
        insert(:data_structure_version,
          metadata: %{"alias" => "foo"},
          data_structure: build(:data_structure, source_id: sid1)
        )

      %{data_structure_id: structure_id2, data_structure: s2} =
        insert(:data_structure_version,
          metadata: %{"alias" => "bar"},
          data_structure: build(:data_structure, source_id: sid2)
        )

      dataset_row = build(:dataset_row, structure: build(:dataset_structure, id: structure_id1))

      condition_row =
        build(:condition_row, structure: build(:dataset_structure, id: structure_id2))

      raw_content1 = build(:raw_content, source_id: sid1)
      raw_content2 = build(:raw_content, source_id: sid2)

      implementation1 =
        insert(:implementation, dataset: [dataset_row], validations: [condition_row])

      implementation2 = insert(:raw_implementation, raw_content: raw_content1)
      implementation3 = insert(:raw_implementation, raw_content: raw_content2)

      [
        sources: [source1, source2],
        structures: [s1, s2],
        implementations: [implementation1, implementation2, implementation3]
      ]
    end

    test "get sources of default implementation", %{implementations: [impl | _]} do
      assert Implementations.get_sources(impl) == ["foo", "bar"]
    end

    test "get sources of raw implementation", %{implementations: [_, impl1, impl2]} do
      assert Implementations.get_sources(impl1) == ["foo"]
      assert Implementations.get_sources(impl2) == ["bar", "baz"]
    end
  end
end
