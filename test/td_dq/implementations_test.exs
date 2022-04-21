defmodule TdDq.ImplementationsTest do
  use TdDd.DataCase

  import TdDd.TestOperators

  alias Ecto.Changeset
  alias TdDq.Implementations
  alias TdDq.Implementations.Implementation
  alias TdDq.Implementations.ImplementationStructure

  @moduletag sandbox: :shared

  setup do
    start_supervised!(TdDq.MockRelationCache)
    start_supervised!(TdDd.Search.MockIndexWorker)
    start_supervised!(TdDq.Cache.RuleLoader)
    start_supervised!(TdDd.Search.StructureEnricher)
    %{id: domain_id} = CacheHelpers.insert_domain()
    [rule: insert(:rule, domain_id: domain_id)]
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
      rule = insert(:rule, business_concept_id: 123)

      insert(:implementation, implementation_key: "ri1", rule: rule)
      insert(:implementation, implementation_key: "ri2", rule: rule)
      insert(:implementation, implementation_key: "ri3", rule: rule)

      assert length(Implementations.list_implementations(%{rule: %{business_concept_id: 123}})) ==
               3
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

    test "returns the implementation with executable flag" do
      implementation = insert(:implementation)
      assert %{executable: true} = Implementations.get_implementation!(implementation.id)
    end

    test "preloads the rule" do
      %{id: id, rule_id: rule_id} = insert(:implementation)
      assert %{rule: rule} = Implementations.get_implementation!(id)
      assert %{id: ^rule_id} = rule
    end

    test "enriches source" do
      %{id: source_id} = source = insert(:source)

      %{id: id} =
        insert(:raw_implementation, raw_content: build(:raw_content, source_id: source_id))

      assert %{raw_content: content} = Implementations.get_implementation!(id, enrich: :source)
      assert %{source: ^source} = content
    end

    test "enriches links" do
      concept_id = System.unique_integer([:positive])

      TdCache.ConceptCache.put(%{
        id: concept_id,
        name: "bc_name",
        updated_at: DateTime.utc_now()
      })

      %{id: id} = insert(:implementation)
      CacheHelpers.insert_link(id, "implementation", "business_concept", concept_id)

      assert %{links: links} = Implementations.get_implementation!(id, enrich: [:links])
      string_concept_id = Integer.to_string(concept_id)

      assert [
               %{
                 resource_id: ^string_concept_id,
                 name: "bc_name"
               }
             ] = links
    end
  end

  describe "get_implementation_by_key/1" do
    test "returns the implementation with given implementation key" do
      %{implementation_key: implementation_key} =
        implementation = insert(:implementation, implementation_key: "My implementation key")

      assert Implementations.get_implementation_by_key!(implementation_key)
             <~> implementation
    end

    test "returns the implementation with executable flag" do
      %{implementation_key: implementation_key} = insert(:implementation)
      assert %{executable: true} = Implementations.get_implementation_by_key!(implementation_key)
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

  describe "create_implementation/3" do
    test "with valid data creates a implementation", %{rule: rule} do
      params =
        string_params_for(:implementation, rule_id: rule.id)
        |> Map.delete("domain_id")

      claims = build(:dq_claims)

      assert {:ok, %{implementation: implementation}} =
               Implementations.create_implementation(rule, params, claims)

      assert implementation.rule_id == params["rule_id"]
    end

    test "with valid data creates a implementation with rule domain_id", %{rule: rule} do
      params =
        string_params_for(:implementation, rule_id: rule.id)
        |> Map.delete("domain_id")

      claims = build(:dq_claims)

      assert {:ok, %{implementation: implementation}} =
               Implementations.create_implementation(rule, params, claims)

      assert implementation.rule_id == params["rule_id"]
      assert implementation.domain_id == rule.domain_id
    end

    test "with duplicated implementation key returns an error", %{rule: rule} do
      impl = insert(:implementation)

      params =
        string_params_for(:implementation,
          rule_id: rule.id,
          domain_id: rule.domain_id,
          implementation_key: impl.implementation_key
        )

      claims = build(:dq_claims)

      assert {:error, :implementation,
              %{valid?: false, errors: [implementation_key: {"duplicated", _}]},
              _} = Implementations.create_implementation(rule, params, claims)
    end

    test "with invalid keywords in raw content of raw implementation returns error", %{rule: rule} do
      raw_content = build(:raw_content, validations: "drop cliente")
      params = string_params_for(:raw_implementation, raw_content: raw_content)
      claims = build(:dq_claims)

      assert {:error, :implementation, %Changeset{valid?: false} = changeset, _} =
               Implementations.create_implementation(rule, params, claims)

      assert %{
               raw_content: %{
                 validations: [{"invalid.validations", [validation: :invalid_content]}]
               }
             } = Changeset.traverse_errors(changeset, & &1)
    end

    test "with valid data for raw implementation creates a implementation", %{rule: rule} do
      %{id: rule_id, domain_id: domain_id} = rule

      params = string_params_for(:raw_implementation, rule_id: rule_id, domain_id: domain_id)
      claims = build(:dq_claims, role: "admin")

      assert {:ok, %{implementation: implementation}} =
               Implementations.create_implementation(rule, params, claims)

      assert %{rule_id: ^rule_id} = implementation
    end

    test "with valid data with single structure creates a implementation", %{rule: rule} do
      params =
        string_params_for(:implementation,
          dataset: [build(:dataset_row)],
          rule_id: rule.id,
          domain_id: rule.domain_id
        )

      claims = build(:dq_claims, role: "admin")

      assert {:ok, %{implementation: implementation}} =
               Implementations.create_implementation(rule, params, claims)

      assert implementation.rule_id == params["rule_id"]
    end

    test "with valid data with timestamp creates a implementation", %{rule: rule} do
      operator = build(:operator, name: "timestamp_gt_timestamp", value_type: "timestamp")

      validation =
        build(:condition_row, value: [%{raw: "2019-12-02 05:35:00"}], operator: operator)

      params =
        string_params_for(:implementation,
          validations: [validation],
          rule_id: rule.id,
          domain_id: rule.domain_id
        )

      claims = build(:dq_claims)

      assert {:ok, %{implementation: implementation}} =
               Implementations.create_implementation(rule, params, claims)

      assert implementation.rule_id == params["rule_id"]
    end

    test "with population in validations", %{rule: rule} do
      %{
        "operator" => %{"name" => name, "value_type" => type},
        "structure" => %{"id" => id},
        "value" => value
      } = condition = string_params_for(:condition_row)

      validations = [string_params_for(:condition_row, population: [condition])]

      params =
        string_params_for(:implementation,
          rule_id: rule.id,
          validations: validations,
          domain_id: rule.domain_id
        )

      claims = build(:dq_claims, role: "admin")

      assert {:ok, %{implementation: %Implementation{validations: [%{population: [clause]}]}}} =
               Implementations.create_implementation(rule, params, claims)

      assert %{
               operator: %{name: ^name, value_type: ^type},
               structure: %{id: ^id},
               value: ^value
             } = clause
    end

    test "creates ImplementationStructure when has dataset", %{rule: rule} do
      %{id: data_structure_id} = insert(:data_structure)

      params =
        string_params_for(:implementation,
          dataset: [%{structure: %{id: data_structure_id}}],
          rule_id: rule.id,
          domain_id: rule.domain_id
        )

      claims = build(:dq_claims, role: "admin")

      assert {:ok, %{implementation: %{id: id}}} =
               Implementations.create_implementation(rule, params, claims)

      assert %Implementation{data_structures: [%{data_structure_id: ^data_structure_id}]} =
               Implementations.get_implementation!(id, preload: :data_structures)
    end

    test "creates ImplementationStructure for raw implementations", %{rule: rule} do
      %{domain_id: domain_id} = rule

      %{id: source_id} = insert(:source, config: %{"job_types" => ["catalog", "profile"]})

      %{data_structure: %{id: data_structure_id}} =
        %{name: data_structure_name} =
        insert(:data_structure_version,
          data_structure: build(:data_structure, domain_ids: [domain_id], source_id: source_id),
          metadata: %{"database" => "db_name"},
          class: "table"
        )

      params =
        string_params_for(:raw_implementation,
          raw_content: %{
            dataset: data_structure_name,
            validations: "validations",
            source_id: source_id,
            database: "db_name"
          }
        )

      claims = build(:dq_claims, role: "admin")

      assert {:ok, %{implementation: %{id: id}}} =
               Implementations.create_implementation(rule, params, claims)

      assert %Implementation{data_structures: [%{data_structure_id: ^data_structure_id}]} =
               Implementations.get_implementation!(id, preload: :data_structures)
    end
  end

  describe "valid_implementation_structures/1" do
    test "returns implementation's dataset structure" do
      %{id: data_structure_id} = insert(:data_structure)

      implementation =
        insert(:implementation,
          dataset: [%{structure: %{id: data_structure_id}}]
        )

      assert [%{id: ^data_structure_id}] =
               Implementations.valid_implementation_structures(implementation)
    end

    test "returns structures for raw implementatation" do
      %{id: source_id} = insert(:source, config: %{"job_types" => ["catalog", "profile"]})

      %{data_structure: %{id: data_structure_id}} =
        %{name: data_structure_name} =
        insert(:data_structure_version,
          data_structure: build(:data_structure, source_id: source_id),
          metadata: %{"database" => "db_name"},
          class: "table"
        )

      implementation =
        insert(:raw_implementation,
          raw_content: %{
            dataset: "word before #{data_structure_name} and after",
            validations: "validations",
            source_id: source_id,
            database: "db_name"
          }
        )

      assert [%{id: ^data_structure_id}] =
               Implementations.valid_implementation_structures(implementation)
    end

    test "filters raw structures by source_id" do
      %{id: source_id1} = insert(:source, config: %{"job_types" => ["catalog", "profile"]})
      %{id: source_id2} = insert(:source, config: %{"job_types" => ["catalog", "profile"]})

      data_structure_name = "same_name"

      insert(:data_structure_version,
        data_structure: build(:data_structure, source_id: source_id1),
        name: data_structure_name,
        metadata: %{"database" => "db_name"},
        class: "table"
      )

      %{data_structure: %{id: data_structure_id}} =
        insert(:data_structure_version,
          data_structure: build(:data_structure, source_id: source_id2),
          name: data_structure_name,
          metadata: %{"database" => "db_name"},
          class: "table"
        )

      implementation =
        insert(:raw_implementation,
          raw_content: %{
            dataset: data_structure_name,
            validations: "validations",
            source_id: source_id2,
            database: "db_name"
          }
        )

      assert [%{id: ^data_structure_id}] =
               Implementations.valid_implementation_structures(implementation)
    end

    test "invalid structure will be filtered" do
      implementation =
        insert(:implementation,
          dataset: [%{structure: %{id: 0}}]
        )

      assert [] == Implementations.valid_implementation_structures(implementation)
    end

    test "returns multiple structures" do
      %{id: data_structure_id1} = insert(:data_structure)
      %{id: data_structure_id2} = insert(:data_structure)

      implementation =
        insert(:implementation,
          dataset: [
            %{structure: %{id: data_structure_id1}},
            %{structure: %{id: 0}},
            %{structure: %{id: data_structure_id2}}
          ]
        )

      assert [
               %{id: ^data_structure_id1},
               %{id: ^data_structure_id2}
             ] = Implementations.valid_implementation_structures(implementation)
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

    test "with population in validations updates data" do
      implementation = insert(:implementation)
      claims = build(:dq_claims)

      %{
        "operator" => %{"name" => name, "value_type" => type},
        "structure" => %{"id" => id},
        "value" => value
      } = condition = string_params_for(:condition_row)

      validations = [string_params_for(:condition_row, population: [condition])]
      update_attrs = %{"validations" => validations}

      assert {:ok, %{implementation: %Implementation{validations: [%{population: [clause]}]}}} =
               Implementations.update_implementation(implementation, update_attrs, claims)

      assert %{
               operator: %{name: ^name, value_type: ^type},
               structure: %{id: ^id},
               value: ^value
             } = clause
    end

    test "domain change when moving to another rule" do
      implementation = insert(:implementation)
      claims = build(:dq_claims)
      domain_id = System.unique_integer([:positive])
      %{id: rule_id} = insert(:rule, domain_id: domain_id)
      update_attrs = string_params_for(:implementation, rule_id: rule_id)

      assert {:ok, %{implementation: updated}} =
               Implementations.update_implementation(implementation, update_attrs, claims)

      assert %{domain_id: ^domain_id, rule_id: ^rule_id} = updated
    end

    test "with invalid data returns error changeset" do
      implementation = insert(:implementation)
      claims = build(:dq_claims)
      udpate_attrs = Map.put(%{}, :dataset, nil)

      assert {:error, :implementation, %Changeset{}, _} =
               Implementations.update_implementation(implementation, udpate_attrs, claims)
    end
  end

  describe "delete_implementation/2" do
    test "deletes the implementation" do
      implementation = insert(:implementation)
      claims = build(:dq_claims)

      assert {:ok, %{implementation: %{__meta__: meta}}} =
               Implementations.delete_implementation(implementation, claims)

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

      claims = build(:dq_claims)

      assert {:ok, %{implementation: %{__meta__: meta}}} =
               Implementations.delete_implementation(implementation, claims)

      assert %{state: :deleted} = meta
      assert is_nil(Repo.get(TdDq.Executions.Execution, execution_id))
    end
  end

  describe "get_structures/1" do
    test "returns all structures present in implementation", %{rule: rule} do
      creation_attrs = %{
        dataset: [
          %{structure: %{id: 1, name: "s1"}},
          %{
            clauses: [%{left: %{id: 2, name: "s2"}, right: %{id: 3, name: "s3"}}],
            structure: %{id: 4, name: "s4"}
          },
          %{clauses: nil, structure: %{id: 5, name: "s5"}}
        ],
        populations: [
          %{
            population: [
              %{
                operator: %{
                  name: "timestamp_gt_timestamp",
                  value_type: "timestamp"
                },
                structure: %{id: 6, name: "s6"},
                value: [%{raw: "2019-12-02 05:35:00"}]
              }
            ]
          }
        ],
        validations: [
          %{
            operator: %{
              name: "timestamp_gt_timestamp",
              value_type: "timestamp",
              value_type_filter: "timestamp"
            },
            structure: %{id: 7, name: "s7"},
            value: [%{raw: "2019-12-02 05:35:00"}]
          },
          %{
            operator: %{
              name: "not_empty"
            },
            structure: %{id: 8, name: "s8"},
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
          populations: creation_attrs.populations,
          validations: creation_attrs.validations
        )

      structures = Implementations.get_structures(rule_implementaton)

      names =
        structures
        |> Enum.sort_by(fn s -> s.id end)
        |> Enum.map(fn s -> s.name end)

      assert names == ["s1", "s2", "s3", "s4", "s5", "s6", "s7", "s8"]
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
        populations: [
          %{
            population: [
              %{
                operator: %{
                  name: "timestamp_gt_timestamp",
                  value_type: "timestamp"
                },
                structure: %{id: 6},
                value: [%{raw: "2019-12-02 05:35:00"}]
              },
              %{
                operator: %{
                  name: "timestamp_gt_timestamp",
                  value_type: "timestamp"
                },
                structure: %{id: 9},
                value: [%{raw: "2019-12-02 05:35:00"}]
              }
            ]
          },
          %{
            population: [
              %{
                operator: %{
                  name: "timestamp_gt_timestamp",
                  value_type: "timestamp"
                },
                structure: %{id: 10},
                value: [%{raw: "2019-12-02 05:35:00"}]
              }
            ]
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
          populations: creation_attrs.populations,
          validations: creation_attrs.validations
        )

      structures_ids = Implementations.get_structure_ids(rule_implementaton)

      assert Enum.sort(structures_ids) == [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
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
        populations: [],
        validations: []
      )

      assert :ok = Implementations.deprecate_implementations()

      %{id: id2} =
        insert(:implementation,
          dataset: [build(:dataset_row, structure: build(:dataset_structure, id: structure_id2))],
          populations: [],
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

    test "get sources of a raw implementation without source_id" do
      implementation =
        insert(:raw_implementation, raw_content: build(:raw_content, source_id: nil))

      assert Implementations.get_sources(implementation) == []
    end
  end

  describe "implementation_structure" do
    @valid_attrs %{deleted_at: "2010-04-17T14:00:00.000000Z", type: :dataset}
    @invalid_attrs %{deleted_at: nil}

    test "create_implementation_structure/1 with valid data creates a implementation_structure" do
      implementation = insert(:implementation)
      data_structure = insert(:data_structure)

      assert {:ok, %ImplementationStructure{} = implementation_structure} =
               Implementations.create_implementation_structure(
                 implementation,
                 data_structure,
                 @valid_attrs
               )

      assert implementation_structure.deleted_at
             <~> DateTime.from_naive!(~N[2010-04-17T14:00:00.000000Z], "Etc/UTC")
    end

    test "create_implementation_structure/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} =
               Implementations.create_implementation_structure(nil, nil, @invalid_attrs)
    end

    test "delete_implementation_structure/1 deletes the implementation_structure" do
      implementation_structure = insert(:implementation_structure)

      assert {:ok, %ImplementationStructure{}} =
               Implementations.delete_implementation_structure(implementation_structure)

      assert_raise Ecto.NoResultsError, fn ->
        Implementations.get_implementation_structure!(implementation_structure.id)
      end
    end
  end
end
