defmodule TdDq.RuleImplementationsTest do
  use TdDq.DataCase

  import Ecto.Query, warn: false
  import TdDq.Factory

  alias TdDq.Cache.RuleLoader
  alias TdDq.MockRelationCache
  alias TdDq.Rules
  alias TdDq.Search.IndexWorker

  setup_all do
    start_supervised(MockRelationCache)
    start_supervised(IndexWorker)
    start_supervised(RuleLoader)
    :ok
  end

  @valid_dataset [
    %{structure: %{id: 14_080}},
    %{
      clauses: [
        %{left: %{id: 14_863}, right: %{id: 4028}}
      ],
      structure: %{id: 3233}
    }
  ]

  @valid_single_dataset [
    %{structure: %{id: 14_080}}
  ]

  @valid_population [
    %{
      operator: %{
        group: "eq",
        name: "eq_number",
        value_type: "number"
      },
      structure: %{id: 6311},
      value: [%{raw: 8}]
    },
    %{
      operator: %{
        group: "in_list",
        name: "string_in_list",
        value_type: "string_list"
      },
      structure: %{id: 3},
      value: [%{raw: ["a", "b"]}]
    }
  ]

  @valid_validations [
    %{
      operator: %{
        group: "eq",
        name: "eq_number",
        value_type: "field"
      },
      structure: %{id: 800},
      value: [%{id: 80}]
    },
    %{
      operator: %{
        group: "in_list",
        name: "string_in_list",
        value_type: "string_list"
      },
      structure: %{id: 81},
      value: [%{raw: ["a", "b"]}]
    }
  ]

  @valid_raw_content %{
    dataset: "clientes c join address a on c.address_id=a.id",
    population: "a.country = 'SPAIN'",
    validations: "a.city is null",
    system: 1
  }

  describe "rule_implementations" do
    alias TdDq.Rules.RuleImplementation

    test "list_rule_implementations/0 returns all rule_implementations" do
      rule_implementation = insert(:rule_implementation)

      assert Enum.map(Rules.list_rule_implementations(), &rule_implementation_preload(&1)) == [
               rule_implementation
             ]
    end

    test "list_rule_implementations/1 returns all rule_implementations by rule" do
      rule1 = insert(:rule)
      rule2 = insert(:rule, name: "#{rule1.name} 1")
      insert(:rule_implementation, implementation_key: "ri1", rule: rule1)
      insert(:rule_implementation, implementation_key: "ri2", rule: rule1)
      insert(:rule_implementation, implementation_key: "ri3", rule: rule1)
      insert(:rule_implementation, implementation_key: "ri4", rule: rule2)
      insert(:rule_implementation_raw, implementation_key: "ri5", rule: rule1)

      assert length(Rules.list_rule_implementations(%{rule_id: rule1.id})) == 4
    end

    test "list_rule_implementations/1 returns non deleted rule_implementations by rule" do
      rule1 = insert(:rule)
      rule2 = insert(:rule, name: "#{rule1.name} 1")
      insert(:rule_implementation, implementation_key: "ri1", rule: rule1)
      insert(:rule_implementation, implementation_key: "ri2", rule: rule1)
      insert(:rule_implementation, implementation_key: "ri3", rule: rule1)
      insert(:rule_implementation, implementation_key: "ri4", rule: rule2)
      insert(:rule_implementation_raw, implementation_key: "ri5", rule: rule2)

      insert(:rule_implementation,
        implementation_key: "ri6",
        rule: rule2,
        deleted_at: DateTime.utc_now()
      )

      assert length(Rules.list_rule_implementations(%{rule_id: rule1.id})) == 3
      assert length(Rules.list_rule_implementations(%{rule_id: rule2.id})) == 2
    end

    test "list_rule_implementations/1 returns all rule_implementations by business_concept_id" do
      rule1 = insert(:rule, business_concept_id: "xyz")
      rule2 = insert(:rule)
      insert(:rule_implementation, implementation_key: "ri1", rule: rule1)
      insert(:rule_implementation, implementation_key: "ri2", rule: rule1)
      insert(:rule_implementation, implementation_key: "ri3", rule: rule1)
      insert(:rule_implementation, implementation_key: "ri4", rule: rule2)

      assert length(Rules.list_rule_implementations(%{rule: %{business_concept_id: "xyz"}})) == 3
    end

    test "list_rule_implementations/1 returns all rule_implementations by status" do
      rule1 = insert(:rule, active: true)
      rule2 = insert(:rule, name: "#{rule1.name} 1")
      insert(:rule_implementation, implementation_key: "ri1", rule: rule1)
      insert(:rule_implementation, implementation_key: "ri2", rule: rule1)
      insert(:rule_implementation, implementation_key: "ri3", rule: rule1)
      insert(:rule_implementation, implementation_key: "ri4", rule: rule2)

      assert length(Rules.list_rule_implementations(%{rule: %{active: true}})) == 3
    end

    test "list_rule_implementations/1 returns deleted rule_implementations when opts provided" do
      rule = insert(:rule, active: true)

      insert(:rule_implementation,
        implementation_key: "ri1",
        rule: rule,
        deleted_at: DateTime.utc_now()
      )

      insert(:rule_implementation, implementation_key: "ri2", rule: rule)
      insert(:rule_implementation, implementation_key: "ri3", rule: rule)

      results = Rules.list_rule_implementations(%{"rule_id" => rule.id}, deleted: true)
      assert length(results) == 1

      assert Enum.any?(results, fn %{implementation_key: implementation_key} ->
               implementation_key == "ri1"
             end)
    end

    test "get_rule_implementation!/1 returns the rule_implementation with given id" do
      rule_implementation = insert(:rule_implementation)

      assert rule_implementation_preload(Rules.get_rule_implementation!(rule_implementation.id)) ==
               rule_implementation
    end

    test "get_rule_implementation!/1 returns the rule_implementation with given id even if it is soft deleted" do
      rule_implementation = insert(:rule_implementation, deleted_at: DateTime.utc_now())

      assert rule_implementation_preload(Rules.get_rule_implementation!(rule_implementation.id)) ==
               rule_implementation
    end

    test "get_rule_implementation/1 returns the rule_implementation with given id" do
      rule_implementation = insert(:rule_implementation)

      assert rule_implementation_preload(Rules.get_rule_implementation(rule_implementation.id)) ==
               rule_implementation
    end

    test "get_rule_implementation_by_key/1 returns the rule_implementation with given implementation key" do
      rule_implementation =
        insert(:rule_implementation, implementation_key: "My implementation key")

      assert rule_implementation_preload(
               Rules.get_rule_implementation_by_key(rule_implementation.implementation_key)
             ) == rule_implementation
    end

    test "get_rule_implementation_by_key/1 returns nil if the rule_implementation with given implementation key has been soft deleted" do
      rule_implementation =
        insert(:rule_implementation,
          implementation_key: "My implementation key",
          deleted_at: DateTime.utc_now()
        )

      assert rule_implementation_preload(
               Rules.get_rule_implementation_by_key(rule_implementation.implementation_key)
             ) == nil
    end

    test "create_rule_implementation/1 with dataset missing clause content returns errors" do
      rule = insert(:rule)

      creation_attrs =
        %{
          rule_id: rule.id,
          population: @valid_population,
          dataset: [
            %{structure: %{id: 14_080}},
            %{structure: %{id: 3233}, clauses: [], join_type: "inner"}
          ],
          validations: @valid_validations
        }
        |> Map.Helpers.stringify_keys()

      assert {:error, %Ecto.Changeset{}, errors} =
               Rules.create_rule_implementation(rule, creation_attrs)

      assert errors |> Map.get(:dataset) |> Enum.any?(&(Map.get(&1, :clauses) == ["required"]))
    end

    test "create_rule_implementation/1 with operator without value and value type creates the implementation correctly" do
      rule = insert(:rule)

      creation_attrs =
        %{
          rule_id: rule.id,
          dataset: @valid_dataset,
          validations: [
            %{
              operator: %{
                name: "empty"
              },
              structure: %{id: 800},
              value: []
            }
          ],
          population: []
        }
        |> Map.Helpers.stringify_keys()

      assert {:ok, %RuleImplementation{} = rule_implementation} =
               Rules.create_rule_implementation(rule, creation_attrs)

      assert rule_implementation.rule_id == creation_attrs["rule_id"]
    end

    test "create_rule_implementation/1 with dataset missing clause right returns errors" do
      rule = insert(:rule)

      creation_attrs =
        %{
          rule_id: rule.id,
          population: @valid_population,
          dataset: [
            %{structure: %{id: 14_080}},
            %{structure: %{id: 3233}, clauses: [%{left: %{id: 14_863}}], join_type: "inner"}
          ],
          validations: @valid_validations
        }
        |> Map.Helpers.stringify_keys()

      assert {:error, %Ecto.Changeset{}, errors} =
               Rules.create_rule_implementation(rule, creation_attrs)

      expected_errors = %{dataset: [%{}, %{clauses: [%{right: ["required"]}]}]}
      assert errors == expected_errors
    end

    test "create_rule_implementation/1 with dataset missing clause key returns errors" do
      rule = insert(:rule)

      creation_attrs =
        %{
          rule_id: rule.id,
          population: @valid_population,
          dataset: [
            %{structure: %{id: 14_080}},
            %{structure: %{id: 3233}, join_type: "inner"}
          ],
          validations: @valid_validations
        }
        |> Map.Helpers.stringify_keys()

      assert {:error, %Ecto.Changeset{}, errors} =
               Rules.create_rule_implementation(rule, creation_attrs)

      assert errors |> Map.get(:dataset) |> Enum.any?(&(Map.get(&1, :clauses) == ["required"]))
    end

    test "create_rule_implementation/1 with invalid population returns errors" do
      rule = insert(:rule)

      creation_attrs =
        %{
          rule_id: rule.id,
          dataset: @valid_dataset,
          population: [
            %{
              value: [%{id: "Whatever"}],
              operator: %{
                name: "eq_number",
                group: "eq",
                value_type: "number"
              },
              structure: %{id: 6311}
            }
          ]
        }
        |> Map.Helpers.stringify_keys()

      assert {:error, %Ecto.Changeset{}, errors} =
               Rules.create_rule_implementation(rule, creation_attrs)

      assert errors |> Map.get(:population) |> Enum.any?(&(Map.get(&1, :value) == ["invalid"]))
    end

    test "create_rule_implementation/1 with missing operator in validations returns errors" do
      rule = insert(:rule)

      creation_attrs =
        %{
          rule_id: rule.id,
          dataset: @valid_dataset,
          population: @valid_population,
          validations: [
            %{
              value: [%{id: 8}],
              structure: %{id: 6311}
            }
          ]
        }
        |> Map.Helpers.stringify_keys()

      assert {:error, %Ecto.Changeset{}, errors} =
               Rules.create_rule_implementation(rule, creation_attrs)

      assert errors
             |> Map.get(:validations)
             |> Enum.any?(&(Map.get(&1, :operator) == ["required"]))
    end

    test "create_rule_implementation/1 with invalid range value in validations returns errors" do
      rule = insert(:rule)

      creation_attrs =
        %{
          rule_id: rule.id,
          dataset: @valid_dataset,
          population: @valid_population,
          validations: [
            %{
              structure: %{id: 6311},
              value: [%{raw: "2019-11-279"}, %{raw: "2019-11-30"}],
              operator: %{
                group: "between",
                name: "date_between_date",
                value_type: "date"
              }
            }
          ]
        }
        |> Map.Helpers.stringify_keys()

      assert {:error, %Ecto.Changeset{}, errors} =
               Rules.create_rule_implementation(rule, creation_attrs)

      assert errors |> Map.get(:validations) |> Enum.any?(&(Map.get(&1, :value) == ["invalid"]))
    end

    test "create_rule_implementation/1 with invalid range dates in validations returns errors" do
      rule = insert(:rule)

      creation_attrs =
        %{
          rule_id: rule.id,
          dataset: @valid_dataset,
          population: @valid_population,
          validations: [
            %{
              structure: %{id: 6311},
              value: [%{raw: "2019-11-30"}, %{raw: "2019-11-29"}],
              operator: %{
                name: "between",
                value_type: "date"
              }
            }
          ]
        }
        |> Map.Helpers.stringify_keys()

      assert {:error, %Ecto.Changeset{}, errors} =
               Rules.create_rule_implementation(rule, creation_attrs)

      assert errors
             |> Map.get(:validations)
             |> Enum.any?(&(Map.get(&1, :value) == ["left_value_must_be_le_than_right"]))
    end

    test "create_rule_implementation/1 with valid data creates a rule_implementation" do
      rule = insert(:rule)

      creation_attrs =
        %{
          rule_id: rule.id,
          dataset: @valid_dataset,
          population: @valid_population,
          validations: @valid_validations
        }
        |> Map.Helpers.stringify_keys()

      assert {:ok, %RuleImplementation{} = rule_implementation} =
               Rules.create_rule_implementation(rule, creation_attrs)

      assert rule_implementation.rule_id == creation_attrs["rule_id"]
    end

    test "create_rule_implementation/1 with invalid keywords in raw content of raw implementation returns error" do
      rule = insert(:rule)

      creation_attrs =
        %{
          rule_id: rule.id,
          implementation_type: "raw",
          raw_content: %{
            dataset: "cliente c join address a on c.address_id=a.id",
            validations: "drop cliente",
            system: 1
          }
        }
        |> Map.Helpers.stringify_keys()

      assert {:error, %Ecto.Changeset{}, errors} =
               Rules.create_rule_implementation(rule, creation_attrs)

      assert errors
             |> Map.get(:raw_content)
             |> Map.get(:validations) == ["invalid_content"]
    end

    test "create_rule_implementation/1 with valid data for raw implementation creates a rule_implementation" do
      rule = insert(:rule)

      creation_attrs =
        %{
          rule_id: rule.id,
          raw_content: @valid_raw_content,
          implementation_type: "raw"
        }
        |> Map.Helpers.stringify_keys()

      assert {:ok, %RuleImplementation{} = rule_implementation} =
               Rules.create_rule_implementation(rule, creation_attrs)

      assert rule_implementation.rule_id == creation_attrs["rule_id"]
    end

    test "create_rule_implementation/1 with valid data with single structure creates a rule_implementation" do
      rule = insert(:rule)

      creation_attrs =
        %{
          rule_id: rule.id,
          dataset: @valid_single_dataset,
          population: @valid_population,
          validations: @valid_validations
        }
        |> Map.Helpers.stringify_keys()

      assert {:ok, %RuleImplementation{} = rule_implementation} =
               Rules.create_rule_implementation(rule, creation_attrs)

      assert rule_implementation.rule_id == creation_attrs["rule_id"]
    end

    test "create_rule_implementation/1 with valid data with timestamp creates a rule_implementation" do
      rule = insert(:rule)

      creation_attrs =
        %{
          rule_id: rule.id,
          dataset: @valid_dataset,
          population: @valid_population,
          validations: [
            %{
              operator: %{
                group: "gt",
                name: "timestamp_gt_timestamp",
                value_type: "timestamp"
              },
              structure: %{id: 12_554},
              value: [%{raw: "2019-12-02 05:35:00"}]
            }
          ]
        }
        |> Map.Helpers.stringify_keys()

      assert {:ok, %RuleImplementation{} = rule_implementation} =
               Rules.create_rule_implementation(rule, creation_attrs)

      assert rule_implementation.rule_id == creation_attrs["rule_id"]
    end

    test "create_rule_implementation/1 with invalid data with timestamp range returns error" do
      rule = insert(:rule)

      creation_attrs =
        %{
          rule_id: rule.id,
          dataset: @valid_dataset,
          population: @valid_population,
          validations: [
            %{
              operator: %{
                name: "between",
                value_type: "timestamp"
              },
              structure: %{id: 12_554},
              value: [
                %{raw: "2019-12-03 05:15:00"},
                %{raw: "2019-12-02 02:10:30"}
              ]
            }
          ]
        }
        |> Map.Helpers.stringify_keys()

      assert {:error, %Ecto.Changeset{}, errors} =
               Rules.create_rule_implementation(rule, creation_attrs)

      assert errors
             |> Map.get(:validations)
             |> Enum.any?(&(Map.get(&1, :value) == ["left_value_must_be_le_than_right"]))
    end

    test "update_rule_implementation/2 with valid data updates the rule_implementation" do
      rule_implementation = insert(:rule_implementation)

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

      assert {:ok, updated_rule_implementation} =
               Rules.update_rule_implementation(rule_implementation, update_attrs)

      assert %RuleImplementation{} = updated_rule_implementation
      assert updated_rule_implementation.rule_id == rule_implementation.rule_id

      assert updated_rule_implementation.implementation_key ==
               rule_implementation.implementation_key

      assert updated_rule_implementation.validations == [
               %TdDq.Rules.RuleImplementation.ConditionRow{
                 operator: %TdDq.Rules.RuleImplementation.Operator{
                   name: "gt",
                   value_type: "timestamp"
                 },
                 structure: %TdDq.Rules.RuleImplementation.Structure{id: 12_554},
                 value: [%{"raw" => "2019-12-30 05:35:00"}]
               }
             ]
    end

    test "update_rule_implementation/2 with invalid data returns error changeset" do
      rule_implementation = insert(:rule_implementation)
      udpate_attrs = Map.put(%{}, :dataset, nil)

      assert {:error, %Ecto.Changeset{}} =
               Rules.update_rule_implementation(rule_implementation, udpate_attrs)

      assert rule_implementation ==
               rule_implementation_preload(Rules.get_rule_implementation!(rule_implementation.id))
    end

    test "delete_rule_implementation/1 deletes the rule_implementation" do
      rule_implementation = insert(:rule_implementation)
      assert {:ok, %RuleImplementation{}} = Rules.delete_rule_implementation(rule_implementation)

      assert_raise Ecto.NoResultsError, fn ->
        Rules.get_rule_implementation!(rule_implementation.id)
      end
    end

    test "change_rule_implementation/1 returns a rule_implementation changeset" do
      rule_implementation = insert(:rule_implementation)
      assert %Ecto.Changeset{} = Rules.change_rule_implementation(rule_implementation)
    end

    test "list_rule_implementations/1 returns all rule_implementations by structure" do
      rule = insert(:rule)

      insert(:rule_implementation,
        implementation_key: "ri11",
        rule: rule
      )

      insert(:rule_implementation,
        implementation_key: "ri12",
        rule: rule
      )

      assert length(Rules.list_rule_implementations(%{"structure_id" => 14_080})) == 2
      assert Rules.list_rule_implementations(%{"structure_id" => 14_863}) == []
      assert length(Rules.list_rule_implementations(%{"structure_id" => 800})) == 2
      assert Rules.list_rule_implementations(%{"structure_id" => 8}) == []
    end

    defp rule_implementation_preload(rule_implementation) do
      rule_implementation
      |> Repo.preload([:rule])
    end
  end
end
