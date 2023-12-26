defmodule TdDq.Implementations.ImplementationTest do
  use TdDd.DataCase

  alias Ecto.Changeset
  alias Elasticsearch.Document
  alias TdDq.Implementations.Implementation

  @implementation %Implementation{domain_id: 123}
  @unsafe "javascript:alert(document)"

  setup do
    identifier_name = "identifier"

    with_identifier = %{
      id: System.unique_integer([:positive]),
      name: "rule_with_identifier",
      label: "rule_with_identifier",
      scope: "dq",
      content: [
        %{
          "fields" => [
            %{
              "cardinality" => "?",
              "default" => "",
              "label" => "Identifier",
              "name" => identifier_name,
              "subscribable" => false,
              "type" => "string",
              "values" => nil,
              "widget" => "identifier"
            },
            %{
              "cardinality" => "1",
              "default" => "",
              "label" => "Text",
              "name" => "text",
              "subscribable" => false,
              "type" => "string",
              "values" => nil,
              "widget" => "text"
            }
          ],
          "name" => ""
        }
      ]
    }

    template_with_identifier = CacheHelpers.insert_template(with_identifier)
    %{name: template_name} = CacheHelpers.insert_template(scope: "dq")

    [
      template_name: template_name,
      template_with_identifier: template_with_identifier,
      identifier_name: identifier_name
    ]
  end

  describe "changeset/1 create new implementation" do
    test "puts a new identifier if the template has an identifier field", %{
      template_with_identifier: template_with_identifier,
      identifier_name: identifier_name
    } do
      %{id: rule_id} = insert(:rule)

      params =
        string_params_for(
          :implementation,
          rule_id: rule_id,
          implementation_key: "foo",
          df_name: template_with_identifier.name,
          df_content: %{"text" => "some text"},
          version: 1,
          status: "draft"
        )

      assert %Changeset{changes: changes} = Implementation.changeset(@implementation, params)

      assert %{df_content: new_content} = changes
      assert %{^identifier_name => _identifier} = new_content
    end

    test "avoids putting new identifier if template lacks an identifier field", %{
      template_name: template_without_identifier_name,
      identifier_name: identifier_name
    } do
      %{id: rule_id} = insert(:rule)

      params =
        string_params_for(
          :implementation,
          rule_id: rule_id,
          implementation_key: "foo",
          df_name: template_without_identifier_name,
          df_content: %{"text" => "some text"}
        )

      assert %Changeset{changes: changes} = Implementation.changeset(@implementation, params)

      assert %{df_content: new_content} = changes
      refute match?(%{^identifier_name => _identifier}, new_content)
    end

    test "puts status to draft if it is currently rejected" do
      implementation = insert(:implementation, status: :rejected)

      changeset = Implementation.changeset(implementation, %{"foo" => "bar"})
      assert Ecto.Changeset.fetch_change!(changeset, :status) == :draft
    end
  end

  describe "changeset/2" do
    test "puts next available implementation_key if none specified and changeset valid" do
      insert(:implementation, implementation_key: "ri0123")
      %{id: rule_id} = insert(:rule)

      params =
        :implementation
        |> string_params_for(rule_id: rule_id)
        |> Map.delete("implementation_key")

      assert %{changes: changes, valid?: true} = Implementation.changeset(@implementation, params)
      assert %{implementation_key: "ri0124"} = changes
    end

    test "does not automatically put implementation_key if one is specified" do
      params = %{implementation_key: "foo"}

      assert %{changes: changes} = Implementation.changeset(@implementation, params)
      assert %{implementation_key: "foo"} = changes
    end

    test "does not automatically put implementation_key if changeset is invalid" do
      params = %{}

      assert %{changes: changes, valid?: false} =
               Implementation.changeset(@implementation, params)

      refute Map.has_key?(changes, :implementation_key)
    end

    test "validates df_content is required if df_name is present", %{template_name: template_name} do
      params = params_for(:implementation, df_name: template_name, df_content: nil)
      assert %{valid?: false, errors: errors} = Implementation.changeset(@implementation, params)
      assert errors[:df_content] == {"can't be blank", [validation: :required]}
    end

    test "validates df_content is valid", %{template_name: template_name} do
      invalid_content = %{"list" => "foo", "string" => "whatever"}
      params = params_for(:implementation, df_name: template_name, df_content: invalid_content)
      assert %{valid?: false, errors: errors} = Implementation.changeset(@implementation, params)
      assert {"invalid content", _detail} = errors[:df_content]
    end

    test "validates df_content is safe", %{template_name: template_name} do
      unsafe_content = %{"list" => "one", "string" => @unsafe}
      params = params_for(:implementation, df_name: template_name, df_content: unsafe_content)
      assert %{valid?: false, errors: errors} = Implementation.changeset(@implementation, params)
      assert {"invalid content", _detail} = errors[:df_content]
    end

    test "validates domain_id is required" do
      implementation = %Implementation{}

      params =
        :implementation
        |> params_for()
        |> Map.delete(:domain_id)

      assert %{valid?: false, errors: errors} = Implementation.changeset(implementation, params)
      assert errors[:domain_id] == {"can't be blank", [validation: :required]}
    end

    test "executable default true field" do
      %{id: rule_id} = insert(:rule)

      params =
        string_params_for(:implementation,
          rule_id: rule_id,
          implementation_key: "foo"
        )

      assert %{valid?: true} = changeset = Implementation.changeset(@implementation, params)
      assert Changeset.get_field(changeset, :executable)
    end

    test "validates result_type value" do
      rule = insert(:rule)
      params = params_for(:implementation, result_type: "foo", rule: rule)
      assert %{valid?: false, errors: errors} = Implementation.changeset(@implementation, params)
      assert {_, [validation: :inclusion, enum: _valid_values]} = errors[:result_type]
    end

    test "validates goal and minimum are between 0 and 100 if result_type is percentage" do
      %{id: rule_id} = insert(:rule)

      params =
        params_for(:implementation,
          result_type: "percentage",
          goal: 101,
          minimum: -1,
          rule_id: rule_id
        )

      assert %{valid?: false, errors: errors} = Implementation.changeset(@implementation, params)
      assert {_, [validation: :number, kind: :less_than_or_equal_to, number: 100]} = errors[:goal]

      assert {_, [validation: :number, kind: :greater_than_or_equal_to, number: 0]} =
               errors[:minimum]
    end

    test "validates goal and minimum are between 0 and 100 if result_type is deviation" do
      rule = insert(:rule)

      params =
        params_for(:implementation,
          result_type: "deviation",
          goal: -1,
          minimum: 101,
          rule: rule
        )

      assert %{valid?: false, errors: errors} = Implementation.changeset(@implementation, params)

      assert {_, [validation: :number, kind: :less_than_or_equal_to, number: 100]} =
               errors[:minimum]

      assert {_, [validation: :number, kind: :greater_than_or_equal_to, number: 0]} =
               errors[:goal]
    end

    test "validates goal and minimum >= 0 if result_type is errors_number" do
      %{id: rule_id} = insert(:rule)

      params =
        params_for(:implementation,
          result_type: "errors_number",
          goal: -1,
          minimum: -1,
          rule_id: rule_id
        )

      assert %{valid?: false, errors: errors} = Implementation.changeset(@implementation, params)

      assert {_, [validation: :number, kind: :greater_than_or_equal_to, number: 0]} =
               errors[:goal]

      assert {_, [validation: :number, kind: :greater_than_or_equal_to, number: 0]} =
               errors[:minimum]
    end

    test "validates goal >= minimum if result_type is percentage" do
      %{id: rule_id} = insert(:rule)

      params =
        params_for(:implementation,
          result_type: "percentage",
          goal: 30,
          minimum: 40,
          rule_id: rule_id
        )

      assert %{valid?: false, errors: errors} = Implementation.changeset(@implementation, params)
      assert errors[:goal] == {"must.be.greater.than.or.equal.to.minimum", []}
    end

    test "validates minimum >= goal if result_type is deviation" do
      %{id: rule_id} = insert(:rule)

      params =
        params_for(:implementation,
          result_type: "deviation",
          goal: 80,
          minimum: 70,
          rule_id: rule_id
        )

      assert %{valid?: false, errors: errors} = Implementation.changeset(@implementation, params)
      assert errors[:minimum] == {"must.be.greater.than.or.equal.to.goal", []}
    end

    test "validates minimum >= goal if result_type is errors_numer" do
      rule = insert(:rule)

      params =
        params_for(:implementation,
          result_type: "errors_number",
          goal: 400,
          minimum: 30,
          rule: rule
        )

      assert %{valid?: false, errors: errors} = Implementation.changeset(@implementation, params)
      assert errors[:minimum] == {"must.be.greater.than.or.equal.to.goal", []}
    end

    test "keeps an already present identifier (i.e., editing)", %{
      template_with_identifier: template_with_identifier,
      identifier_name: identifier_name
    } do
      # Existing identifier previously put by the create changeset
      existing_identifier = "00000000-0000-0000-0000-000000000000"

      implementation =
        insert(:implementation,
          df_name: template_with_identifier.name,
          df_content: %{identifier_name => existing_identifier}
        )

      params =
        string_params_for(
          :implementation,
          df_content: %{"text" => "some update"},
          df_name: template_with_identifier.name
        )

      assert %Changeset{changes: changes} = Implementation.changeset(implementation, params)

      assert %{df_content: new_content} = changes
      assert %{^identifier_name => ^existing_identifier} = new_content
    end

    test "keeps an already present identifier (i.e., editing) if extraneous identifier attr is passed",
         %{
           template_with_identifier: template_with_identifier,
           identifier_name: identifier_name
         } do
      # Existing identifier previously put by the create changeset
      existing_identifier = "00000000-0000-0000-0000-000000000000"

      implementation =
        insert(:implementation,
          df_name: template_with_identifier.name,
          df_content: %{identifier_name => existing_identifier}
        )

      params =
        string_params_for(
          :implementation,
          df_content: %{
            "text" => "some update",
            identifier_name => "11111111-1111-1111-1111-111111111111"
          },
          df_name: template_with_identifier.name
        )

      assert %Changeset{changes: changes} = Implementation.changeset(implementation, params)

      assert %{df_content: new_content} = changes
      assert %{^identifier_name => ^existing_identifier} = new_content
    end

    test "puts an identifier if there is not already one and the template has an identifier field",
         %{template_with_identifier: template_with_identifier, identifier_name: identifier_name} do
      # Ingest version has no identifier but its template does
      # This happens if identifier is added to template after ingest creation
      # Test an update to the ingest version in this state.
      %{df_content: content} =
        implementation = insert(:implementation, df_name: template_with_identifier.name)

      # Just to make sure factory does not add identifier
      refute match?(%{^identifier_name => _identifier}, content)

      params =
        string_params_for(
          :implementation,
          df_content: %{"text" => "some update"},
          df_name: template_with_identifier.name
        )

      assert %Changeset{changes: changes} = Implementation.changeset(implementation, params)

      assert %{df_content: new_content} = changes
      assert %{^identifier_name => _identifier} = new_content
    end
  end

  describe "encode" do
    test "encoded implementation includes validation modifier" do
      rule = insert(:rule)

      creation_attrs = %{
        validations: [
          %{
            operator: %{
              name: "timestamp_gt_timestamp",
              value_type: "timestamp",
              value_type_filter: "timestamp"
            },
            structure: %{id: 7, name: "s7"},
            value: [%{raw: "2019-12-02 05:35:00"}],
            modifier: build(:modifier),
            value_modifier: [build(:modifier)]
          }
        ]
      }

      implementation_key = "rik1"

      rule_implementation =
        insert(:implementation,
          implementation_key: implementation_key,
          rule: rule,
          validations: creation_attrs.validations
        )

      assert %{
               validations: [
                 %{
                   value_modifier: [
                     %{
                       name: _,
                       params: %{}
                     }
                   ],
                   modifier: %{
                     name: _,
                     params: %{}
                   }
                 }
               ]
             } = Document.encode(rule_implementation)
    end

    test "encoded implementation includes populations" do
      rule = insert(:rule)

      operator = %{
        name: "timestamp_gt_timestamp",
        value_type: "timestamp",
        value_type_filter: "timestamp"
      }

      structure = %{id: structure_id, name: structure_name} = %{id: 7, name: "s7"}
      value = [%{raw: "2019-12-02 05:35:00"}]

      creation_attrs = %{
        populations: [
          %{
            population: [
              %{
                operator: operator,
                structure: structure,
                value: value
              },
              %{
                operator: operator,
                structure: structure,
                value: value
              }
            ]
          },
          %{
            population: [
              %{
                operator: operator,
                structure: structure,
                value: value
              }
            ]
          }
        ]
      }

      implementation_key = "rik1"

      rule_implementation =
        insert(:implementation,
          implementation_key: implementation_key,
          rule: rule,
          populations: creation_attrs.populations
        )

      assert %{
               populations: [
                 %{
                   population: [
                     %{
                       operator: ^operator,
                       structure: %{id: ^structure_id, name: ^structure_name},
                       value: value_encoded
                     },
                     %{
                       operator: ^operator,
                       structure: %{id: ^structure_id, name: ^structure_name},
                       value: value_encoded
                     }
                   ]
                 },
                 %{
                   population: [
                     %{
                       operator: ^operator,
                       structure: %{id: ^structure_id, name: ^structure_name},
                       value: value_encoded
                     }
                   ]
                 }
               ]
             } = Document.encode(rule_implementation)
    end

    test "encoded implementation includes population (backward compatibility)" do
      rule = insert(:rule)

      operator = %{
        name: "timestamp_gt_timestamp",
        value_type: "timestamp",
        value_type_filter: "timestamp"
      }

      structure = %{id: structure_id, name: structure_name} = %{id: 7, name: "s7"}
      value = [%{raw: "2019-12-02 05:35:00"}]

      creation_attrs = %{
        populations: [
          %{
            population: [
              %{
                operator: operator,
                structure: structure,
                value: value
              },
              %{
                operator: operator,
                structure: structure,
                value: value
              }
            ]
          },
          %{
            population: [
              %{
                operator: operator,
                structure: structure,
                value: value
              }
            ]
          }
        ]
      }

      implementation_key = "rik1"

      rule_implementation =
        insert(:implementation,
          implementation_key: implementation_key,
          rule: rule,
          populations: creation_attrs.populations
        )

      assert %{
               population: [
                 %{
                   operator: ^operator,
                   structure: %{id: ^structure_id, name: ^structure_name},
                   value: ^value
                 },
                 %{
                   operator: ^operator,
                   structure: %{id: ^structure_id, name: ^structure_name},
                   value: ^value
                 }
               ]
             } = Document.encode(rule_implementation)
    end

    test "encoded implementation includes segments" do
      rule = insert(:rule)

      structure_1 = %{
        id: 9,
        name: "s9",
        external_id: nil,
        parent_index: nil,
        path: [],
        system: nil,
        type: nil
      }

      structure_2 = %{
        id: 10,
        name: "s10",
        external_id: nil,
        parent_index: nil,
        path: [],
        system: nil,
        type: nil
      }

      creation_attrs = %{
        segments: [
          %{
            structure: structure_1
          },
          %{
            structure: structure_2
          }
        ]
      }

      implementation_key = "seg1"

      rule_implementation =
        insert(:implementation,
          implementation_key: implementation_key,
          rule: rule,
          segments: creation_attrs.segments
        )

      assert %{
               segments: [
                 %{
                   structure: ^structure_1
                 },
                 %{
                   structure: ^structure_2
                 }
               ]
             } = Document.encode(rule_implementation)
    end

    test "encodes ruleless implementations" do
      operator = %{
        name: "timestamp_gt_timestamp",
        value_type: "timestamp",
        value_type_filter: "timestamp"
      }

      structure = %{id: structure_id, name: structure_name} = %{id: 7, name: "s7"}
      value = [%{raw: "2019-12-02 05:35:00"}]

      creation_attrs = %{
        populations: [
          %{
            population: [
              %{
                operator: operator,
                structure: structure,
                value: value
              },
              %{
                operator: operator,
                structure: structure,
                value: value
              }
            ]
          },
          %{
            population: [
              %{
                operator: operator,
                structure: structure,
                value: value
              }
            ]
          }
        ]
      }

      implementation_key = "rik1"

      rule_implementation =
        insert(:ruleless_implementation,
          implementation_key: implementation_key,
          populations: creation_attrs.populations
        )

      assert %{
               population: [
                 %{
                   operator: ^operator,
                   structure: %{id: ^structure_id, name: ^structure_name},
                   value: ^value
                 },
                 %{
                   operator: ^operator,
                   structure: %{id: ^structure_id, name: ^structure_name},
                   value: ^value
                 }
               ]
             } = Document.encode(rule_implementation)
    end
  end
end
