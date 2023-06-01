defmodule TdDq.ImplementationsTest do
  use TdDd.DataCase

  import TdDd.TestOperators

  alias Ecto.Changeset
  alias TdCache.ImplementationCache
  alias TdCache.Redix
  alias TdCache.Redix.Stream
  alias TdDd.Search.MockIndexWorker
  alias TdDq.Implementations
  alias TdDq.Implementations.Implementation
  alias TdDq.Implementations.ImplementationStructure
  alias TdDq.Rules.RuleResults

  @moduletag sandbox: :shared
  @stream TdCache.Audit.stream()

  setup do
    on_exit(fn -> Redix.del!(@stream) end)

    start_supervised!(TdDq.MockRelationCache)
    start_supervised!(MockIndexWorker)
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

      assert Implementations.list_implementations() ||| [implementation]
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
        validation: [%{conditions: [validation_row]}]
      )

      insert(:implementation,
        rule: rule,
        implementation_key: "ri12",
        dataset: [dataset_row],
        validation: [%{conditions: [validation_row]}]
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

  describe "get_implementations_ref" do
    test "return implementation list with implementation_ref relation" do
      %{id: id1} = insert(:implementation)
      %{id: id2} = insert(:implementation)
      %{id: id3} = insert(:implementation, implementation_ref: id2)
      %{id: id4} = insert(:implementation)
      %{id: id5} = insert(:implementation, implementation_ref: id4)

      [id1, id2, id3, id4, id5]
      |> Implementations.get_implementations_ref()
      |> assert_lists_equal([
        [id1, id1],
        [id2, id2],
        [id3, id2],
        [id4, id4],
        [id5, id4]
      ])
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

      %{id: id, implementation_ref: implementation_ref} = insert(:implementation)

      CacheHelpers.insert_link(
        implementation_ref,
        "implementation_ref",
        "business_concept",
        concept_id
      )

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

  describe "get_published_implementation_by_key/2" do
    test "returns the implementation with given implementation key with status published" do
      %{implementation_key: implementation_key} =
        implementation =
        insert(:implementation, implementation_key: "My implementation key", status: :published)

      assert Implementations.get_published_implementation_by_key(implementation_key)
             <~> {:ok, implementation}
    end

    test "returns the implementation with executable flag " do
      %{implementation_key: implementation_key} = insert(:implementation, status: :published)

      assert {:ok, %{executable: true}} =
               Implementations.get_published_implementation_by_key(implementation_key)
    end

    test "not found if the implementation with given implementation key has been deprecated" do
      %{implementation_key: implementation_key} =
        insert(:implementation,
          implementation_key: "My implementation key",
          deleted_at: DateTime.utc_now(),
          status: :deprecated
        )

      assert {:error, :not_found} =
               Implementations.get_published_implementation_by_key(implementation_key)
    end
  end

  describe "create_implementation/4" do
    test "with valid data creates a implementation", %{rule: rule} do
      params =
        string_params_for(:implementation, rule_id: rule.id)
        |> Map.delete("domain_id")

      claims = build(:claims)

      assert {:ok, %{implementation: implementation}} =
               Implementations.create_implementation(rule, params, claims)

      assert implementation.rule_id == params["rule_id"]
      assert implementation.implementation_ref == implementation.id
    end

    test "with valid data creates a implementation with rule domain_id", %{rule: rule} do
      params =
        string_params_for(:implementation, rule_id: rule.id)
        |> Map.delete("domain_id")

      claims = build(:claims)

      assert {:ok, %{implementation: implementation}} =
               Implementations.create_implementation(rule, params, claims)

      assert implementation.rule_id == params["rule_id"]
      assert implementation.domain_id == rule.domain_id
      assert implementation.implementation_ref == implementation.id
    end

    test "with duplicated draft implementation key returns an error", %{rule: rule} do
      impl = insert(:implementation)

      params =
        string_params_for(:implementation,
          rule_id: rule.id,
          domain_id: rule.domain_id,
          implementation_key: impl.implementation_key
        )

      claims = build(:claims)

      assert {:error, :implementation,
              %{valid?: false, errors: [implementation_key: {"duplicated", constraint}]},
              _} = Implementations.create_implementation(rule, params, claims)

      assert "draft_implementation_key_index" = constraint[:constraint_name]
    end

    test "with duplicated pending_approval implementation key returns an error", %{rule: rule} do
      impl = insert(:implementation, status: "pending_approval")

      params =
        string_params_for(:implementation,
          rule_id: rule.id,
          domain_id: rule.domain_id,
          implementation_key: impl.implementation_key,
          status: "pending_approval"
        )

      claims = build(:claims)

      assert {:error, :implementation,
              %{valid?: false, errors: [implementation_key: {"duplicated", _}]},
              _} = Implementations.create_implementation(rule, params, claims)
    end

    test "with duplicated rejected implementation key returns an error", %{rule: rule} do
      impl = insert(:implementation, status: "rejected")

      params =
        string_params_for(:implementation,
          rule_id: rule.id,
          domain_id: rule.domain_id,
          implementation_key: impl.implementation_key,
          status: "rejected"
        )

      claims = build(:claims)

      assert {:error, :implementation,
              %{valid?: false, errors: [implementation_key: {"duplicated", _}]},
              _} = Implementations.create_implementation(rule, params, claims)
    end

    test "with duplicated published draft implementation key returns an error", %{rule: rule} do
      impl = insert(:implementation, status: "published")

      params =
        string_params_for(:implementation,
          rule_id: rule.id,
          domain_id: rule.domain_id,
          implementation_key: impl.implementation_key,
          status: "published"
        )

      claims = build(:claims)

      assert {:error, :implementation,
              %{valid?: false, errors: [implementation_key: {"duplicated", _}]},
              _} = Implementations.create_implementation(rule, params, claims)
    end

    test "can be more than one deprecated implementation", %{rule: rule} do
      impl = insert(:implementation, status: "deprecated")

      params =
        string_params_for(:implementation,
          rule_id: rule.id,
          domain_id: rule.domain_id,
          implementation_key: impl.implementation_key,
          status: "deprecated"
        )

      claims = build(:claims)

      assert {:ok, %{implementation: _implementation}} =
               Implementations.create_implementation(rule, params, claims)
    end

    test "with invalid keywords in raw content of raw implementation returns error", %{rule: rule} do
      raw_content = build(:raw_content, validations: "drop cliente")
      params = string_params_for(:raw_implementation, raw_content: raw_content)
      claims = build(:claims)

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
      claims = build(:claims, role: "admin")

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

      claims = build(:claims, role: "admin")

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
          validation: [[validation]],
          rule_id: rule.id,
          domain_id: rule.domain_id
        )

      claims = build(:claims)

      assert {:ok, %{implementation: implementation}} =
               Implementations.create_implementation(rule, params, claims)

      assert implementation.rule_id == params["rule_id"]
    end

    test "with valid data with reference data creates a implementation", %{rule: rule} do
      operator = build(:operator, name: "eq", value_type: "field")

      validation_value = %{
        id: 1,
        name: "foo_reference_dataset",
        parent_index: 2,
        type: "reference_dataset_field"
      }

      validation = build(:condition_row, value: [validation_value], operator: operator)

      params =
        string_params_for(:implementation,
          validation: [[validation]],
          rule_id: rule.id,
          domain_id: rule.domain_id
        )

      claims = build(:claims)

      assert {:ok, %{implementation: %{validation: [%{conditions: [%{value: [value]}]}]}}} =
               Implementations.create_implementation(rule, params, claims)

      assert [[%{"value" => [^value]}]] = params["validation"]
    end

    test "with population in validations", %{rule: rule} do
      %{
        "operator" => %{"name" => name, "value_type" => type},
        "structure" => %{"id" => id},
        "value" => value
      } = condition = string_params_for(:condition_row)

      validation = [[string_params_for(:condition_row, population: [condition])]]

      params =
        string_params_for(:implementation,
          rule_id: rule.id,
          validation: validation,
          domain_id: rule.domain_id
        )

      claims = build(:claims, role: "admin")

      assert {:ok,
              %{
                implementation: %Implementation{
                  validation: [
                    %{
                      conditions: [
                        %{population: [clause]}
                      ]
                    }
                  ]
                }
              }} = Implementations.create_implementation(rule, params, claims)

      assert %{
               operator: %{name: ^name, value_type: ^type},
               structure: %{id: ^id},
               value: ^value
             } = clause
    end

    test "creates ImplementationStructure when has dataset", %{rule: rule} do
      %{id: dataset_data_structure_id} = insert(:data_structure)
      %{id: validation_data_structure_id} = insert(:data_structure)

      params =
        string_params_for(:implementation,
          dataset: [%{structure: %{id: dataset_data_structure_id}}],
          validation: [
            %{
              conditions: [
                %{build(:condition_row) | structure: %{id: validation_data_structure_id}}
              ]
            }
          ],
          rule_id: rule.id,
          domain_id: rule.domain_id
        )

      claims = build(:claims, role: "admin")

      assert {:ok, %{implementation: %{id: id}}} =
               Implementations.create_implementation(rule, params, claims)

      assert %Implementation{
               data_structures: [
                 %{data_structure_id: ^dataset_data_structure_id, type: :dataset},
                 %{data_structure_id: ^validation_data_structure_id, type: :validation}
               ]
             } = Implementations.get_implementation!(id, preload: :data_structures)
    end

    test "creates dataset ImplementationStructure for raw implementations", %{rule: rule} do
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

      claims = build(:claims, role: "admin")

      assert {:ok, %{implementation: %{id: id}}} =
               Implementations.create_implementation(rule, params, claims)

      assert %Implementation{data_structures: [%{data_structure_id: ^data_structure_id}]} =
               Implementations.get_implementation!(id, preload: :data_structures)
    end
  end

  describe "enrich_implementation_structures/1" do
    test "enriches implementation dataset structures" do
      %{data_structure_id: data_structure_id, name: structure_name} =
        insert(:data_structure_version)

      implementation =
        insert(:implementation,
          dataset: [%{structure: %{id: data_structure_id}}]
        )

      assert %{dataset: [%{structure: %{name: ^structure_name}}]} =
               Implementations.enrich_implementation_structures(implementation)
    end

    test "enriches implementation dataset clauses structures" do
      %{data_structure_id: data_structure_id, name: structure_name} =
        insert(:data_structure_version)

      %{data_structure_id: left_data_structure_id, name: left_structure_name} =
        insert(:data_structure_version)

      %{data_structure_id: right_data_structure_id, name: right_structure_name} =
        insert(:data_structure_version)

      implementation =
        insert(:implementation,
          dataset: [
            %{
              structure: %{id: data_structure_id},
              clauses: [
                %{left: %{id: left_data_structure_id}, right: %{id: right_data_structure_id}}
              ]
            }
          ]
        )

      assert %{
               dataset: [
                 %{
                   structure: %{name: ^structure_name},
                   clauses: [
                     %{left: %{name: ^left_structure_name}, right: %{name: ^right_structure_name}}
                   ]
                 }
               ]
             } = Implementations.enrich_implementation_structures(implementation)
    end

    test "enriches implementation dataset with reference_dataset" do
      %{id: id, name: dataset_name} = insert(:reference_dataset)

      implementation =
        insert(:implementation,
          dataset: [%{structure: %{id: id, type: "reference_dataset"}}]
        )

      assert %{dataset: [%{structure: %{name: ^dataset_name, type: "reference_dataset"}}]} =
               Implementations.enrich_implementation_structures(implementation)
    end

    test "implementation with invalid reference_dataset will simply return the invalid structure withou enriching" do
      implementation =
        insert(:implementation,
          dataset: [%{structure: %{id: 1, type: "reference_dataset"}}]
        )

      assert %{dataset: [%{structure: %{type: "reference_dataset"}}]} =
               Implementations.enrich_implementation_structures(implementation)
    end

    test "enriches implementation dataset clauses with reference_dataset_field" do
      %{id: id, name: dataset_name} = insert(:reference_dataset)

      %{data_structure_id: left_data_structure_id, name: left_structure_name} =
        insert(:data_structure_version)

      implementation =
        insert(:implementation,
          dataset: [
            %{
              structure: %{id: id, type: "reference_dataset"},
              clauses: [
                %{
                  left: %{id: left_data_structure_id},
                  right: %{name: "reference_dataset_field_name", type: "reference_dataset_field"}
                }
              ]
            }
          ]
        )

      assert %{
               dataset: [
                 %{
                   structure: %{name: ^dataset_name, type: "reference_dataset"},
                   clauses: [
                     %{
                       left: %{name: ^left_structure_name},
                       right: %{
                         name: "reference_dataset_field_name",
                         type: "reference_dataset_field"
                       }
                     }
                   ]
                 }
               ]
             } = Implementations.enrich_implementation_structures(implementation)
    end

    test "enriches implementation validations" do
      %{data_structure_id: data_structure_id, name: structure_name} =
        insert(:data_structure_version)

      implementation =
        insert(:implementation,
          validation: [
            %{conditions: [%{build(:condition_row) | structure: %{id: data_structure_id}}]}
          ]
        )

      assert %{validation: [%{conditions: [%{structure: %{name: ^structure_name}}]}]} =
               Implementations.enrich_implementation_structures(implementation)
    end

    test "enriches implementation validations with reference_dataset_field" do
      implementation =
        insert(:implementation,
          validation: [
            %{
              validations: [
                %{
                  build(:condition_row)
                  | structure: %{
                      name: "reference_dataset_field_name",
                      type: "reference_dataset_field"
                    }
                }
              ]
            }
          ]
        )

      assert %{
               validation: [
                 %{
                   validations: [
                     %{
                       structure: %{
                         name: "reference_dataset_field_name",
                         type: "reference_dataset_field"
                       }
                     }
                   ]
                 }
               ]
             } = Implementations.enrich_implementation_structures(implementation)
    end

    test "implementation with invalida reference_dataset_field validation value
          will simply return the invalid structure withou enriching" do
      operator = build(:operator, name: "eq", value_type: "field")

      validation_value = %{
        "id" => 1,
        "name" => "foo_reference_dataset",
        "parent_index" => 2,
        "type" => "reference_dataset_field"
      }

      condition = build(:condition_row, value: [validation_value], operator: operator)

      implementation =
        insert(
          :implementation,
          dataset: [%{structure: %{id: 1, type: "reference_dataset"}}],
          populations: [],
          segments: [],
          validation: [
            %{conditions: [condition]}
          ]
        )

      assert %{validation: [%{conditions: [%{value: [_]}]}]} =
               Implementations.enrich_implementation_structures(implementation)
    end

    test "enriches implementation populations" do
      %{data_structure_id: data_structure_id, name: structure_name} =
        insert(:data_structure_version)

      implementation =
        insert(:implementation,
          populations: [
            %{conditions: [%{build(:condition_row) | structure: %{id: data_structure_id}}]}
          ]
        )

      assert %{populations: [%{conditions: [%{structure: %{name: ^structure_name}}]}]} =
               Implementations.enrich_implementation_structures(implementation)
    end

    test "enriches implementation populations with reference_dataset_field" do
      implementation =
        insert(:implementation,
          populations: [
            %{
              population: [
                %{
                  build(:condition_row)
                  | structure: %{
                      name: "reference_dataset_field_name",
                      type: "reference_dataset_field"
                    }
                }
              ]
            }
          ]
        )

      assert %{
               populations: [
                 %{
                   population: [
                     %{
                       structure: %{
                         name: "reference_dataset_field_name",
                         type: "reference_dataset_field"
                       }
                     }
                   ]
                 }
               ]
             } = Implementations.enrich_implementation_structures(implementation)
    end

    test "enriches implementation segments" do
      %{data_structure_id: data_structure_id, name: structure_name} =
        insert(:data_structure_version)

      implementation =
        insert(:implementation,
          segments: [%{structure: %{id: data_structure_id}}]
        )

      assert %{segments: [%{structure: %{name: ^structure_name}}]} =
               Implementations.enrich_implementation_structures(implementation)
    end
  end

  describe "valid_dataset_implementation_structures/1" do
    test "returns implementation's dataset structure" do
      %{id: data_structure_id} = insert(:data_structure)

      implementation =
        insert(:implementation,
          dataset: [%{structure: %{id: data_structure_id}}]
        )

      assert [%{id: ^data_structure_id}] =
               Implementations.valid_dataset_implementation_structures(implementation)
    end

    test "returns structures for raw implementation" do
      %{id: source_id} = insert(:source, config: %{"job_types" => ["catalog", "profile"]})

      %{data_structure: %{id: data_structure_id}, name: data_structure_name} =
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
               Implementations.valid_dataset_implementation_structures(implementation)
    end

    test "returns only class table structures for raw implementation" do
      %{id: source_id} = insert(:source, config: %{"job_types" => ["catalog", "profile"]})

      %{data_structure: %{id: data_structure_id}, name: data_structure_name} =
        insert(:data_structure_version,
          data_structure: build(:data_structure, source_id: source_id),
          metadata: %{"database" => "db_name"},
          class: "table"
        )

      %{name: field_data_structure_name} =
        insert(:data_structure_version,
          data_structure: build(:data_structure, source_id: source_id),
          metadata: %{"database" => "db_name"},
          class: "field"
        )

      implementation =
        insert(:raw_implementation,
          raw_content: %{
            dataset: "word before #{data_structure_name} #{field_data_structure_name}",
            validations: "validations",
            source_id: source_id,
            database: "db_name"
          }
        )

      assert [%{id: ^data_structure_id}] =
               Implementations.valid_dataset_implementation_structures(implementation)
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
               Implementations.valid_dataset_implementation_structures(implementation)
    end

    test "reference_dataset structures will be filtered" do
      %{id: data_structure_id} = insert(:data_structure)

      implementation =
        insert(:implementation,
          dataset: [%{structure: %{id: data_structure_id, type: "reference_dataset"}}]
        )

      assert [] == Implementations.valid_dataset_implementation_structures(implementation)
    end

    test "invalid structure will be filtered" do
      implementation =
        insert(:implementation,
          dataset: [%{structure: %{id: 0}}]
        )

      assert [] == Implementations.valid_dataset_implementation_structures(implementation)
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
             ] = Implementations.valid_dataset_implementation_structures(implementation)
    end
  end

  describe "valid_validation_implementation_structures/1" do
    test "returns implementation's validations structure" do
      %{id: data_structure_id} = insert(:data_structure)

      implementation =
        insert(:implementation,
          validation: [
            %{conditions: [%{build(:condition_row) | structure: %{id: data_structure_id}}]}
          ]
        )

      assert [%{id: ^data_structure_id}] =
               Implementations.valid_validation_implementation_structures(implementation)
    end

    test "filters reference_dataset_field structures" do
      %{id: data_structure_id} = insert(:data_structure)

      implementation =
        insert(:implementation,
          validation: [
            %{
              validations: [
                %{
                  build(:condition_row)
                  | structure: %{id: data_structure_id, type: "reference_dataset_field"}
                }
              ]
            }
          ]
        )

      assert [] = Implementations.valid_validation_implementation_structures(implementation)
    end

    test "returns validation field structures for raw implementatation" do
      %{id: source_id} = insert(:source, config: %{"job_types" => ["catalog", "profile"]})

      %{data_structure: %{id: data_structure_id}, name: data_structure_name} =
        insert(:data_structure_version,
          data_structure: build(:data_structure, source_id: source_id),
          metadata: %{
            "database" => "db_name",
            "table" => "table_name"
          },
          class: "field"
        )

      %{data_structure: %{id: data_structure_id_2}, name: data_structure_name_2} =
        insert(:data_structure_version,
          data_structure: build(:data_structure, source_id: source_id),
          metadata: %{
            "database" => "db_name",
            "table" => "table_name"
          },
          class: "field"
        )

      %{data_structure: %{id: data_structure_id_3}, name: data_structure_name_3} =
        insert(:data_structure_version,
          data_structure: build(:data_structure, source_id: source_id),
          metadata: %{
            "database" => "db_name",
            "table" => "table_name"
          },
          class: "field"
        )

      implementation =
        insert(:raw_implementation,
          raw_content: %{
            dataset: "table_name",
            validations:
              "word before test.#{data_structure_name} and test.#{data_structure_name_2}='whatever' and length(#{data_structure_name_3})>2 and after",
            source_id: source_id,
            database: "db_name"
          }
        )

      assert [
               %{id: ^data_structure_id},
               %{id: ^data_structure_id_2},
               %{id: ^data_structure_id_3}
             ] = Implementations.valid_validation_implementation_structures(implementation)
    end

    test "returns validation only for structures with table in dataset case insensitive" do
      %{id: source_id} = insert(:source, config: %{"job_types" => ["catalog", "profile"]})

      %{data_structure: %{id: data_structure_id}, name: data_structure_name} =
        insert(:data_structure_version,
          data_structure: build(:data_structure, source_id: source_id),
          metadata: %{
            "database" => "db_name",
            "table" => "table_name"
          },
          class: "field"
        )

      %{name: no_table_data_structure_name} =
        insert(:data_structure_version,
          data_structure: build(:data_structure, source_id: source_id),
          metadata: %{
            "database" => "db_name",
            "table" => "other_table"
          },
          class: "field"
        )

      implementation =
        insert(:raw_implementation,
          raw_content: %{
            dataset: "tAbLe_NaMe",
            validations: "#{data_structure_name} #{no_table_data_structure_name}",
            source_id: source_id,
            database: "db_name"
          }
        )

      assert [%{id: ^data_structure_id}] =
               Implementations.valid_validation_implementation_structures(implementation)
    end
  end

  describe "create_ruleless_implementation/3" do
    setup do
      [claims: build(:claims, role: "admin")]
    end

    test "with valid data creates a implementation", %{claims: claims} do
      params = string_params_for(:ruleless_implementation)

      assert {:ok, %{implementation: implementation}} =
               Implementations.create_ruleless_implementation(params, claims)

      assert implementation.implementation_key == params["implementation_key"]
    end

    test "with valid data for raw implementation creates a implementation", %{claims: claims} do
      params = string_params_for(:raw_implementation, rule_id: nil, domain_id: 123)

      assert {:ok, %{implementation: implementation}} =
               Implementations.create_ruleless_implementation(params, claims)

      refute implementation.rule_id
    end

    test "links data structures", %{claims: claims} do
      %{id: structure_id} = insert(:data_structure)

      params =
        string_params_for(:ruleless_implementation,
          dataset: [build(:dataset_row, structure: build(:dataset_structure, id: structure_id))]
        )

      assert {:ok, %{data_structures: [%{data_structure_id: ^structure_id}]}} =
               Implementations.create_ruleless_implementation(params, claims)
    end
  end

  describe "update_implementation/3" do
    test "with valid data updates the implementation" do
      implementation = insert(:implementation)
      claims = build(:claims)

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
          validation: [%{conditions: validations}]
        }
        |> Map.Helpers.stringify_keys()

      assert {:ok, %{implementation: updated_implementation}} =
               Implementations.update_implementation(implementation, update_attrs, claims)

      assert %Implementation{} = updated_implementation
      assert updated_implementation.rule_id == implementation.rule_id

      assert updated_implementation.implementation_key ==
               implementation.implementation_key

      assert updated_implementation.validation == [
               %TdDq.Implementations.Conditions{
                 conditions: [
                   %TdDq.Implementations.ConditionRow{
                     operator: %TdDq.Implementations.Operator{
                       name: "gt",
                       value_type: "timestamp"
                     },
                     structure: %TdDq.Implementations.Structure{id: 12_554},
                     value: [%{"raw" => "2019-12-30 05:35:00"}]
                   }
                 ]
               }
             ]
    end

    test "update a implementations when it is a rejected state" do
      implementation = insert(:implementation, status: :rejected)
      claims = build(:claims)

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
          validation: [%{conditions: validations}]
        }
        |> Map.Helpers.stringify_keys()

      assert {:ok, %{implementation: updated_implementation}} =
               Implementations.update_implementation(implementation, update_attrs, claims)

      assert %Implementation{} = updated_implementation
      assert updated_implementation.rule_id == implementation.rule_id

      assert updated_implementation.implementation_key ==
               implementation.implementation_key

      assert updated_implementation.validation == [
               %TdDq.Implementations.Conditions{
                 conditions: [
                   %TdDq.Implementations.ConditionRow{
                     operator: %TdDq.Implementations.Operator{
                       name: "gt",
                       value_type: "timestamp"
                     },
                     structure: %TdDq.Implementations.Structure{id: 12_554},
                     value: [%{"raw" => "2019-12-30 05:35:00"}]
                   }
                 ]
               }
             ]
    end

    test "with population in validations updates data" do
      implementation = insert(:implementation)
      claims = build(:claims)

      %{
        "operator" => %{"name" => name, "value_type" => type},
        "structure" => %{"id" => id},
        "value" => value
      } = condition = string_params_for(:condition_row)

      validation = [[string_params_for(:condition_row, population: [condition])]]
      update_attrs = %{"validation" => validation}

      assert {:ok,
              %{
                implementation: %Implementation{
                  validation: [%{conditions: [%{population: [clause]}]}]
                }
              }} = Implementations.update_implementation(implementation, update_attrs, claims)

      assert %{
               operator: %{name: ^name, value_type: ^type},
               structure: %{id: ^id},
               value: ^value
             } = clause
    end

    test "domain change for all implementations when moving one to another rule" do
      implementation_ref = insert(:implementation, status: "versioned")

      implementation =
        insert(:implementation, status: "published", implementation_ref: implementation_ref.id)

      claims = build(:claims)
      domain_id = System.unique_integer([:positive])
      %{id: rule_id} = insert(:rule, domain_id: domain_id)
      update_attrs = string_params_for(:implementation, rule_id: rule_id)

      assert {:ok, %{implementations_moved: {2, updated}}} =
               Implementations.update_implementation(implementation, update_attrs, claims)

      updated
      |> Enum.each(fn updated_implementation ->
        assert %{domain_id: ^domain_id} = updated_implementation
      end)
    end

    test "childs implementations are moved when moving any implementation to another rule" do
      claims = build(:claims)
      domain_id = System.unique_integer([:positive])
      rule_from = insert(:rule, domain_id: domain_id)
      %{id: rule_id} = insert(:rule, domain_id: domain_id)
      implementation_ref = insert(:implementation, status: "versioned", rule: rule_from)

      implementation =
        insert(
          :implementation,
          status: "published",
          implementation_ref: implementation_ref.id,
          rule: rule_from
        )

      update_attrs = string_params_for(:implementation, rule_id: rule_id)

      assert {:ok, %{implementations_moved: {2, updated}}} =
               Implementations.update_implementation(implementation, update_attrs, claims)

      updated
      |> Enum.each(fn updated_implementation ->
        assert %{rule_id: ^rule_id} = updated_implementation
      end)
    end

    test "with invalid data returns error changeset" do
      implementation = insert(:implementation)
      claims = build(:claims)
      udpate_attrs = Map.put(%{}, :dataset, nil)

      assert {:error, :implementation, %Changeset{}, _} =
               Implementations.update_implementation(implementation, udpate_attrs, claims)
    end

    test "creates ImplementationStructure when updating implementation" do
      implementation = insert(:implementation)

      %{id: dataset_data_structure_id} = insert(:data_structure)
      %{id: validation_data_structure_id} = insert(:data_structure)

      update_attrs =
        %{
          dataset: [%{structure: %{id: dataset_data_structure_id}}],
          validation: [
            %{
              conditions: [
                %{
                  operator: %{
                    name: "gt",
                    value_type: "timestamp"
                  },
                  structure: %{id: validation_data_structure_id},
                  value: [%{raw: "2019-12-30 05:35:00"}]
                }
              ]
            }
          ]
        }
        |> Map.Helpers.stringify_keys()

      claims = build(:claims, role: "admin")

      assert {:ok, %{implementation: %{id: id}}} =
               Implementations.update_implementation(implementation, update_attrs, claims)

      assert %Implementation{
               data_structures: [
                 %{data_structure_id: ^dataset_data_structure_id, type: :dataset},
                 %{data_structure_id: ^validation_data_structure_id, type: :validation}
               ]
             } = Implementations.get_implementation!(id, preload: :data_structures)
    end

    test "deleted ImplementationStructure will not be recreated when updating implementation" do
      implementation = insert(:implementation)

      %{id: dataset_data_structure_id} = insert(:data_structure)
      %{id: validation_data_structure_id} = insert(:data_structure)

      insert(:implementation_structure,
        implementation_id: implementation.id,
        data_structure_id: dataset_data_structure_id,
        type: :dataset,
        deleted_at: "2022-05-04 00:00:00"
      )

      update_attrs =
        %{
          dataset: [%{structure: %{id: dataset_data_structure_id}}],
          validation: [
            %{
              conditions: [
                %{
                  operator: %{
                    name: "gt",
                    value_type: "timestamp"
                  },
                  structure: %{id: validation_data_structure_id},
                  value: [%{raw: "2019-12-30 05:35:00"}]
                }
              ]
            }
          ]
        }
        |> Map.Helpers.stringify_keys()

      claims = build(:claims, role: "admin")

      assert {:ok, _} =
               Implementations.update_implementation(implementation, update_attrs, claims)

      assert %Implementation{
               data_structures: [
                 %{data_structure_id: ^validation_data_structure_id, type: :validation}
               ]
             } = Implementations.get_implementation!(implementation.id, preload: :data_structures)
    end

    test "update basic implementation to default implementation" do
      implementation = insert(:basic_implementation, status: "published")
      claims = build(:claims, role: "admin")
      %{id: dataset_data_structure_id} = insert(:data_structure)
      %{id: validation_data_structure_id} = insert(:data_structure)

      validations = [
        %{
          conditions: [
            %{
              operator: %{
                name: "gt",
                value_type: "timestamp"
              },
              structure: %{id: validation_data_structure_id},
              value: [%{raw: "2019-12-30 05:35:00"}]
            }
          ]
        }
      ]

      update_attrs =
        %{
          dataset: [%{structure: %{id: dataset_data_structure_id}}],
          validation: validations,
          implementation_type: "default",
          executable: true,
          implementation_key: implementation.implementation_key,
          goal: implementation.goal,
          minimum: implementation.minimum,
          status: :published
        }
        |> Map.Helpers.stringify_keys()

      assert {:ok, %{implementation: updated_implementation}} =
               Implementations.update_implementation(implementation, update_attrs, claims)

      assert %Implementation{} = updated_implementation
      assert updated_implementation.rule_id == implementation.rule_id

      assert updated_implementation.implementation_key ==
               implementation.implementation_key

      assert updated_implementation.implementation_type == "default"
      assert updated_implementation.version == implementation.version + 1

      assert [_ | _] = updated_implementation.dataset

      assert updated_implementation.validation == [
               %TdDq.Implementations.Conditions{
                 conditions: [
                   %TdDq.Implementations.ConditionRow{
                     operator: %TdDq.Implementations.Operator{
                       name: "gt",
                       value_type: "timestamp"
                     },
                     structure: %TdDq.Implementations.Structure{id: validation_data_structure_id},
                     value: [%{"raw" => "2019-12-30 05:35:00"}]
                   }
                 ]
               }
             ]
    end
  end

  describe "delete_implementation/2" do
    setup do
      claims = build(:claims)
      domain = build(:domain)

      %{id: rule_id} = rule = insert(:rule)

      %{id: implementation_ref_id} =
        implementation_v1 =
        insert(
          :implementation,
          rule: rule,
          version: 1,
          domain_id: domain.id,
          status: :versioned
        )

      implementation_v2 =
        insert(
          :implementation,
          rule: rule,
          version: 2,
          domain_id: domain.id,
          status: :deprecated,
          implementation_ref: implementation_ref_id
        )

      [
        claims: claims,
        implementation_v1: implementation_v1,
        implementation_v2: implementation_v2,
        rule_id: rule_id
      ]
    end

    test "deletes the implementation" do
      %{id: implementation_ref_id} = implementation = insert(:implementation)
      claims = build(:claims)

      assert {:ok, %{implementations: {1, _}}} =
               Implementations.delete_implementation(implementation, claims)

      assert nil == Implementations.get_implementation(implementation_ref_id)
    end

    test "deletes the implementation and related data_structures" do
      %{id: implementation_ref_id} = implementation = insert(:implementation)

      %{id: implementation_structure_id} =
        insert(:implementation_structure, implementation: implementation)

      claims = build(:claims)

      assert {:ok, %{implementations: {1, _}}} =
               Implementations.delete_implementation(implementation, claims)

      assert nil == Implementations.get_implementation(implementation_ref_id)
      assert is_nil(Repo.get(ImplementationStructure, implementation_structure_id))
    end

    test "deletes the implementation linked to executions" do
      %{id: id} = insert(:execution_group)
      implementation = %{id: implementation_id} = insert(:implementation, status: :draft)

      %{id: execution_id} =
        insert(:execution,
          group_id: id,
          implementation_id: implementation_id,
          result: insert(:rule_result)
        )

      claims = build(:claims)

      assert {:ok, %{implementations: {1, _}}} =
               Implementations.delete_implementation(implementation, claims)

      assert nil == Implementations.get_implementation(implementation_id)
      assert is_nil(Repo.get(TdDq.Executions.Execution, execution_id))
    end

    test "deleting a deprecated implementation also deletes everything related with implementation_ref, including previous versions",
         %{
           implementation_v1: implementation_v1,
           implementation_v2: implementation_v2,
           rule_id: rule_id,
           claims: claims
         } do
      %{id: implementation_ref_id} = implementation_v1
      %{data_structure_id: ds_id} = insert(:data_structure_version)

      insert(:implementation_structure,
        data_structure_id: ds_id,
        implementation_id: implementation_ref_id
      )

      %{id: implementation_v2_id} = implementation_v2

      %{id: rule_result_id} =
        insert(:rule_result,
          rule_id: rule_id,
          implementation_id: implementation_v2_id
        )

      %{id: remediation_id} =
        insert(
          :remediation,
          rule_result_id: rule_result_id
        )

      Implementations.delete_implementation(implementation_v2, claims)

      assert nil == Implementations.get_implementation(implementation_ref_id)

      assert [] =
               ImplementationStructure
               |> where([i], i.implementation_id == ^implementation_ref_id)
               |> Repo.all()

      assert nil == RuleResults.get_rule_result(rule_result_id)

      assert nil == TdDq.Remediations.get_remediation(remediation_id)
    end

    test "deleting a deprecated implementation also deletes its previous versions from cache",
         %{
           implementation_v1: implementation_v1,
           implementation_v2: implementation_v2,
           claims: claims
         } do
      %{id: implementation_ref_id} = implementation_v1
      %{id: implementation_v2_id} = implementation_v2

      CacheHelpers.put_implementation(implementation_v1)
      CacheHelpers.put_implementation(implementation_v2)

      %{id: concept_id} = CacheHelpers.insert_concept()

      CacheHelpers.insert_link(
        implementation_ref_id,
        "implementation_ref",
        "business_concept",
        concept_id
      )

      Implementations.delete_implementation(implementation_v2, claims)

      assert {:ok, nil} = ImplementationCache.get(implementation_v2_id)
      assert {:ok, nil} = ImplementationCache.get(implementation_ref_id)
    end

    test "deleted deprecated implementation generates audit events",
         %{
           implementation_v1: implementation_v1,
           implementation_v2: implementation_v2,
           claims: claims
         } do
      %{id: implementation_v1_id} = implementation_v1
      implementation_v1_id_string = "#{implementation_v1_id}"

      %{id: implementation_v2_id} = implementation_v2
      implementation_v2_id_string = "#{implementation_v2_id}"

      {:ok, %{audit: [event_id1, event_id2]}} =
        Implementations.delete_implementation(implementation_v2, claims)

      assert {:ok,
              [
                %{
                  event: "implementation_deleted",
                  resource_id: ^implementation_v1_id_string
                }
              ]} = Stream.range(:redix, @stream, event_id1, event_id1, transform: :range)

      assert {:ok,
              [
                %{
                  event: "implementation_deleted",
                  resource_id: ^implementation_v2_id_string
                }
              ]} = Stream.range(:redix, @stream, event_id2, event_id2, transform: :range)
    end

    test "deleted deprecated implementation calls elastic reindex",
         %{
           implementation_v1: implementation_v1,
           implementation_v2: implementation_v2,
           claims: claims
         } do
      %{id: implementation_ref_id} = implementation_v1
      %{id: implementation_v2_id} = implementation_v2

      Implementations.delete_implementation(implementation_v2, claims)

      assert [implementation_ref_id, implementation_v2_id] |||
               MockIndexWorker.calls()[:delete_implementations]
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
            conditions: [
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
        validation: [
          %{
            conditions: [
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
        ],
        segments: [
          %{
            structure: %{id: 9, name: "s9"}
          },
          %{
            structure: %{id: 10, name: "s10"}
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
          validation: creation_attrs.validation,
          segments: creation_attrs.segments
        )

      structures = Implementations.get_structures(rule_implementaton)

      names =
        structures
        |> Enum.sort_by(fn s -> s.id end)
        |> Enum.map(fn s -> s.name end)

      assert names == ["s1", "s2", "s3", "s4", "s5", "s6", "s7", "s8", "s9", "s10"]
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
            conditions: [
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
            conditions: [
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
        validation: [
          %{
            conditions: [
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
          },
          %{
            conditions: [
              %{
                operator: %{
                  name: "timestamp_gt_timestamp",
                  value_type: "timestamp",
                  value_type_filter: "timestamp"
                },
                structure: %{id: 13},
                value: [%{raw: "2019-12-02 05:35:00"}]
              },
              %{
                operator: %{
                  name: "not_empty"
                },
                structure: %{id: 14},
                value: nil
              }
            ]
          }
        ],
        segments: [
          %{
            structure: %{id: 11}
          },
          %{
            structure: %{id: 12}
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
          validation: creation_attrs.validation,
          segments: creation_attrs.segments
        )

      structures_ids = Implementations.get_structure_ids(rule_implementaton)

      assert Enum.sort(structures_ids) == [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14]
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

      assert {:ok, %{deprecated: {2, deprecated}}} = Implementations.deprecate([id1, id2, id3])

      assert_lists_equal(deprecated, [id1, id3], &(&1.id == &2 and &1.status == :deprecated))
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
        validation: [],
        segments: []
      )

      assert :ok = Implementations.deprecate_implementations()

      %{id: id2} =
        insert(:implementation,
          dataset: [build(:dataset_row, structure: build(:dataset_structure, id: structure_id2))],
          populations: [],
          validation: [],
          segments: []
        )

      %{id: id3} = insert(:implementation)

      assert {:ok, %{deprecated: deprecated}} = Implementations.deprecate_implementations()
      assert {2, implementations} = deprecated
      assert ids = Enum.map(implementations, & &1.id)
      assert id2 in ids
      assert id3 in ids
    end

    test "only deprecates implementations with unexisting reference dataset" do
      %{id: id} = insert(:reference_dataset)

      insert(:implementation,
        dataset: [build(:dataset_row, structure: %{id: id, type: "reference_dataset"})],
        populations: [],
        validation: [],
        segments: []
      )

      assert :ok = Implementations.deprecate_implementations()

      %{id: id_to_deprecate} =
        insert(:implementation,
          dataset: [%{structure: %{id: id + 1, type: "reference_dataset"}}]
        )

      assert {:ok, %{deprecated: deprecated}} = Implementations.deprecate_implementations()
      assert {1, [%{id: ^id_to_deprecate}]} = deprecated
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

      validation = [%{conditions: [condition_row]}]

      raw_content1 = build(:raw_content, source_id: sid1)
      raw_content2 = build(:raw_content, source_id: sid2)

      implementation1 = insert(:implementation, dataset: [dataset_row], validation: validation)

      implementation2 = insert(:raw_implementation, raw_content: raw_content1)
      implementation3 = insert(:raw_implementation, raw_content: raw_content2)

      [
        sources: [source1, source2],
        structures: [s1, s2],
        implementations: [implementation1, implementation2, implementation3]
      ]
    end

    test "get sources of default implementation", %{implementations: [impl | _]} do
      assert Implementations.get_sources(impl) ||| ["foo", "bar"]
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
    test "create_implementation_structure/1 with valid data creates a implementation_structure" do
      %{id: implementation_id} = implementation = insert(:implementation)
      %{id: data_structure_id} = data_structure = insert(:data_structure)

      assert {:ok,
              %ImplementationStructure{} = %{
                implementation_id: ^implementation_id,
                data_structure_id: ^data_structure_id,
                type: :dataset
              }} =
               Implementations.create_implementation_structure(
                 implementation,
                 data_structure,
                 %{type: :dataset}
               )
    end

    test "reindex implementation after create implementation_structure" do
      MockIndexWorker.clear()

      %{id: implementation_ref_id} = insert(:implementation, version: 1)

      %{id: implementation_id} =
        implementation =
        insert(:implementation, version: 2, implementation_ref: implementation_ref_id)

      data_structure = insert(:data_structure)

      Implementations.create_implementation_structure(
        implementation,
        data_structure,
        %{type: :dataset}
      )

      [
        {:reindex_implementations, implementation_reindexed}
      ] = MockIndexWorker.calls()

      assert implementation_reindexed ||| [implementation_id, implementation_ref_id]
    end

    test "reindex implementation by structures ids related to implementation_structure" do
      MockIndexWorker.clear()

      %{id: implementation_id} = insert(:implementation, version: 1, status: :published)

      %{id: data_structure_id} = insert(:data_structure)

      insert(:implementation_structure,
        data_structure_id: data_structure_id,
        implementation_id: implementation_id
      )

      Implementations.reindex_implementations_structures([data_structure_id])

      [
        {:reindex_implementations, implementation_reindexed}
      ] = MockIndexWorker.calls()

      assert implementation_reindexed ||| [implementation_id]
    end

    test "create_implementation_structure/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} =
               Implementations.create_implementation_structure(%Implementation{}, nil, %{})
    end

    test "creating a deleted implementation_structure will undelete it" do
      implementation = insert(:implementation)
      data_structure = insert(:data_structure)

      insert(:implementation_structure,
        implementation: implementation,
        data_structure: data_structure,
        type: :dataset,
        deleted_at: "2022-05-04 00:00:00"
      )

      assert {:ok, %ImplementationStructure{} = implementation_structure} =
               Implementations.create_implementation_structure(
                 implementation,
                 data_structure,
                 %{type: :dataset}
               )

      assert is_nil(implementation_structure.deleted_at)
    end

    test "delete_implementation_structure/1 softly deletes the implementation_structure" do
      implementation_structure = insert(:implementation_structure)

      assert {:ok, %ImplementationStructure{}} =
               Implementations.delete_implementation_structure(implementation_structure)

      assert_raise Ecto.NoResultsError, fn ->
        Implementations.get_implementation_structure!(implementation_structure.id)
      end

      assert %{deleted_at: deleted_at} =
               TdDd.Repo.get!(ImplementationStructure, implementation_structure.id)

      refute is_nil(deleted_at)
    end

    test "reindex implementation when delete_implementation_structure/1" do
      MockIndexWorker.clear()
      domain = build(:domain)

      %{id: implementation_ref_id} = implementation_ref = insert(:implementation, version: 1)

      %{id: implementation_id} =
        insert(:implementation, version: 2, implementation_ref: implementation_ref_id)

      implementation_structure =
        insert(:implementation_structure,
          implementation: implementation_ref,
          data_structure: build(:data_structure, domain_ids: [domain.id])
        )

      assert {:ok, %ImplementationStructure{}} =
               Implementations.delete_implementation_structure(implementation_structure)

      [
        {:reindex_implementations, implementation_reindexed}
      ] = MockIndexWorker.calls()

      assert implementation_reindexed ||| [implementation_id, implementation_ref_id]
    end

    test "when update implementation new implementation_structures will be created linked to implementation ref" do
      claims = build(:claims)
      domain = build(:domain)

      %{id: dataset_structure_id} =
        dataset_structure = insert(:data_structure, domain_ids: [domain.id])

      %{id: validation_structure_id} = insert(:data_structure, domain_ids: [domain.id])

      dataset_row =
        build(
          :dataset_row,
          structure: build(:dataset_structure, id: dataset_structure_id)
        )

      %{id: implementation_ref_id} =
        implementation_ref =
        insert(:implementation,
          status: :versioned,
          version: 1,
          domain_id: domain.id,
          dataset: [dataset_row]
        )

      implementation =
        insert(:implementation,
          status: :published,
          version: 2,
          domain_id: domain.id,
          dataset: [dataset_row],
          implementation_ref: implementation_ref_id
        )

      insert(:implementation_structure,
        implementation: implementation_ref,
        data_structure: insert(:data_structure, domain_ids: [domain.id])
      )

      deleted_data_structure_link =
        insert(:implementation_structure,
          deleted_at: DateTime.utc_now(),
          implementation: implementation_ref,
          data_structure: dataset_structure
        )

      validations = [
        %{
          operator: %{
            name: "gt",
            value_type: "timestamp"
          },
          structure: %{id: validation_structure_id},
          value: [%{raw: "2019-12-30 05:35:00"}]
        }
      ]

      update_attrs =
        %{
          validation: [%{conditions: validations}],
          status: :draft
        }
        |> Map.Helpers.stringify_keys()

      assert {:ok, _} =
               implementation
               |> Repo.preload(data_structures: :data_structure, rule: [])
               |> Implementations.update_implementation(
                 update_attrs,
                 claims
               )

      assert %{data_structures: data_structures_links} =
               Implementation
               |> where([i], i.id == ^implementation_ref_id)
               |> preload(:data_structures)
               |> Repo.one()

      assert length(data_structures_links) == 2

      assert Enum.all?(data_structures_links, fn dsl ->
               dsl.implementation_id == implementation_ref_id
             end)

      assert %{data_structure_id: ^dataset_structure_id} =
               deleted_link =
               ImplementationStructure
               |> where(
                 [is],
                 is.data_structure_id == ^deleted_data_structure_link.data_structure_id
               )
               |> where([is], is.implementation_id == ^implementation_ref_id)
               |> Repo.one()

      refute is_nil(deleted_link.deleted_at)
    end
  end

  describe "last?/1" do
    test "returns true if the given implementation is the latest version with the same key" do
      %{implementation_ref: implementation_ref} =
        first = insert(:implementation, version: 1, status: "deprecated")

      second = insert(:implementation, implementation_ref: implementation_ref, version: 2)
      refute Implementations.last?(first)
      assert Implementations.last?(second)
      assert Implementations.last?(%Implementation{id: 0, implementation_ref: 0})
    end
  end

  describe "get_linked_implementation/1" do
    test "return draft if are not published implementation" do
      %{id: implementation_id, implementation_ref: implementation_ref} =
        insert(:implementation, version: 1, status: "draft")

      %{id: linked_implementation_id} =
        Implementations.get_linked_implementation!(implementation_ref)

      assert ^implementation_id = linked_implementation_id
    end

    test "return published implementation if exists" do
      %{implementation_ref: implementation_ref} =
        insert(:implementation, version: 1, status: "draft")

      %{id: implementation_id} =
        insert(:implementation,
          version: 2,
          status: "published",
          implementation_ref: implementation_ref
        )

      %{id: linked_implementation_id} =
        Implementations.get_linked_implementation!(implementation_ref)

      assert ^implementation_id = linked_implementation_id
    end

    test "return deprecated implementation if are not published implementation" do
      %{implementation_ref: implementation_ref} =
        insert(:implementation, version: 1, status: "versioned")

      %{id: implementation_id} =
        insert(:implementation,
          version: 2,
          status: "deprecated",
          implementation_ref: implementation_ref
        )

      %{id: linked_implementation_id} =
        Implementations.get_linked_implementation!(implementation_ref)

      assert ^implementation_id = linked_implementation_id
    end
  end
end
