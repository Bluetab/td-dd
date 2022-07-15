defmodule TdDqWeb.ImplementationControllerTest do
  use TdDqWeb.ConnCase

  use PhoenixSwagger.SchemaTest, "priv/static/swagger_dq.json"

  import Mox

  alias TdDd.DataStructures.Hierarchy
  alias TdDd.DataStructures.RelationTypes
  alias TdDq.Implementations

  @moduletag sandbox: :shared

  @valid_dataset [
    %{structure: %{id: 14_080}},
    %{clauses: [%{left: %{id: 14_863}, right: %{id: 4028}}], structure: %{id: 3233}}
  ]

  @validations [
    %{
      operator: %{
        name: "gt",
        value_type: "timestamp"
      },
      structure: %{id: 12_554},
      value: [%{raw: "2019-12-02 05:35:00"}]
    }
  ]

  @populations [
    [
      %{
        value: [%{id: 11}],
        operator: %{
          name: "eq",
          value_type: "number"
        },
        structure: %{id: 60_311}
      }
    ]
  ]

  @identifier_template %{
    id: System.unique_integer([:positive]),
    label: "identifier_test",
    name: "identifier_test",
    scope: "dq",
    content: [
      %{
        "name" => "Identifier Template",
        "fields" => [
          %{
            "cardinality" => "1",
            "label" => "identifier_field",
            "name" => "identifier_field",
            "subscribable" => false,
            "type" => "string",
            "values" => nil,
            "widget" => "identifier"
          }
        ]
      }
    ]
  }

  @rule_implementation_permissions [:manage_quality_rule_implementations, :view_quality_rule]
  @imp_raw_permissions [:manage_raw_quality_rule_implementations, :view_quality_rule]
  @imp_ruleless_permissions [
    :manage_ruleless_implementations,
    :manage_quality_rule_implementations,
    :view_quality_rule
  ]
  @imp_raw_ruleless_permissions [
    :manage_raw_quality_rule_implementations,
    :manage_ruleless_implementations,
    :view_quality_rule
  ]

  @rule_implementation_attr %{
    implementation_key: "a1",
    dataset: @valid_dataset,
    validations: @validations,
    result_type: "percentage",
    minimum: 50,
    goal: 100
  }

  @raw_implementation_attr %{
    implementation_key: "a1",
    implementation_type: "raw",
    raw_content: %{
      dataset: "cliente c join address a on c.address_id=a.id",
      population: nil,
      source_id: 88,
      validations: "c.city = 'MADRID'"
    },
    result_type: "percentage",
    minimum: 50,
    goal: 100
  }

  setup_all do
    start_supervised!(TdDd.Search.MockIndexWorker)
    start_supervised!(TdDd.Search.Cluster)
    start_supervised!(TdDq.Cache.RuleLoader)
    :ok
  end

  setup :verify_on_exit!

  setup do
    start_supervised!(TdDd.Search.StructureEnricher)

    [implementation: insert(:implementation)]
  end

  describe "GET /api/implementations/:id" do
    @tag authentication: [role: "admin"]
    test "includes the source external_id in the response", %{conn: conn, swagger_schema: schema} do
      %{id: source_id, external_id: source_external_id} = insert(:source)

      %{id: id} =
        insert(:raw_implementation, raw_content: build(:raw_content, source_id: source_id))

      assert %{"data" => data} =
               conn
               |> get(Routes.implementation_path(conn, :show, id))
               |> validate_resp_schema(schema, "ImplementationResponse")
               |> json_response(:ok)

      assert %{"raw_content" => content} = data
      assert %{"source" => source} = content
      assert %{"external_id" => ^source_external_id} = source
    end

    @tag authentication: [role: "admin"]
    test "includes executable in response", %{conn: conn, swagger_schema: schema} do
      %{id: id} = insert(:implementation)

      assert %{"data" => %{"executable" => true}} =
               conn
               |> get(Routes.implementation_path(conn, :show, id))
               |> validate_resp_schema(schema, "ImplementationResponse")
               |> json_response(:ok)
    end

    @tag authentication: [role: "admin"]
    test "includes related structures with current version and system in the response", %{
      conn: conn,
      swagger_schema: schema
    } do
      %{id: system_id, name: system_name} = insert(:system)
      %{id: data_structure_id} = data_structure = insert(:data_structure, system_id: system_id)

      %{name: structure_name} =
        insert(:data_structure_version, data_structure_id: data_structure_id)

      %{id: id} = implementation = insert(:implementation)

      insert(:implementation_structure,
        implementation: implementation,
        data_structure: data_structure
      )

      assert %{"data" => %{"data_structures" => data_structures}} =
               conn
               |> get(Routes.implementation_path(conn, :show, id))
               |> validate_resp_schema(schema, "ImplementationResponse")
               |> json_response(:ok)

      assert [
               %{
                 "implementation_id" => ^id,
                 "type" => "dataset",
                 "data_structure" => %{
                   "id" => ^data_structure_id,
                   "system" => %{"name" => ^system_name},
                   "current_version" => %{
                     "name" => ^structure_name
                   }
                 }
               }
             ] = data_structures
    end

    @tag authentication: [role: "admin"]
    test "data_structures has enriched path", %{
      conn: conn,
      swagger_schema: schema
    } do
      domain_id = System.unique_integer([:positive])
      %{id: system_id} = insert(:system)

      %{id: data_structure_id} =
        data_structure =
        insert(:data_structure,
          system_id: system_id,
          domain_ids: [domain_id]
        )

      %{id: dsv_id} = insert(:data_structure_version, data_structure: data_structure)

      %{id: dsv_parent_id, name: parent_name} =
        insert(:data_structure_version,
          data_structure:
            build(:data_structure,
              system_id: system_id,
              domain_ids: [domain_id]
            )
        )

      %{id: id} = implementation = insert(:implementation)

      insert(:implementation_structure,
        implementation: implementation,
        data_structure: data_structure
      )

      insert(:data_structure_relation,
        parent_id: dsv_parent_id,
        child_id: dsv_id,
        relation_type_id: RelationTypes.default_id!()
      )

      Hierarchy.update_hierarchy([dsv_id])

      assert %{"data" => %{"data_structures" => data_structures}} =
               conn
               |> get(Routes.implementation_path(conn, :show, id))
               |> validate_resp_schema(schema, "ImplementationResponse")
               |> json_response(:ok)

      assert [
               %{
                 "implementation_id" => ^id,
                 "data_structure" => %{
                   "id" => ^data_structure_id,
                   "current_version" => %{
                     "path" => [^parent_name]
                   }
                 }
               }
             ] = data_structures
    end

    @tag authentication: [
           user_name: "non_admin",
           permissions: [
             :view_data_structure,
             :view_quality_rule
           ]
         ]
    test "hides related data structures without permission", %{
      conn: conn,
      domain: domain
    } do
      %{id: system_id, name: system_name} = insert(:system)

      %{id: data_structure_id} =
        data_structure = insert(:data_structure, system_id: system_id, domain_ids: [domain.id])

      %{name: structure_name} =
        insert(:data_structure_version, data_structure_id: data_structure_id)

      %{id: id} = implementation = insert(:implementation, domain_id: domain.id)

      insert(:implementation_structure,
        implementation: implementation,
        data_structure: data_structure
      )

      insert(:implementation_structure,
        implementation: implementation,
        data_structure: build(:data_structure)
      )

      assert %{"data" => %{"data_structures" => data_structures}} =
               conn
               |> get(Routes.implementation_path(conn, :show, id))
               |> json_response(:ok)

      assert [
               %{
                 "implementation_id" => ^id,
                 "type" => "dataset",
                 "data_structure" => %{
                   "id" => ^data_structure_id,
                   "system" => %{"name" => ^system_name},
                   "current_version" => %{
                     "name" => ^structure_name
                   }
                 }
               }
             ] = data_structures
    end

    @tag authentication: [
           user_name: "non_admin",
           permissions: [
             :view_published_business_concepts,
             :view_quality_rule,
             :execute_quality_rule_implementations
           ]
         ]
    test "includes execute action if user is assigned execute_quality_rule_implementations permission",
         %{conn: conn, swagger_schema: schema, domain: domain} do
      %{id: id} = insert(:implementation, domain_id: domain.id, status: "published")

      assert %{
               "_actions" => %{
                 "execute" => %{
                   "method" => "POST"
                 }
               }
             } =
               conn
               |> get(Routes.implementation_path(conn, :show, id))
               |> validate_resp_schema(schema, "ImplementationResponse")
               |> json_response(:ok)
    end

    @tag authentication: [
           user_name: "non_admin",
           permissions: [:view_published_business_concepts, :view_quality_rule]
         ]
    test "does not include execute action if user is not assigned execute_quality_rule_implementations permission",
         %{conn: conn, swagger_schema: schema, domain: domain} do
      %{id: id} = insert(:implementation, domain_id: domain.id)

      refute match?(
               %{
                 "_actions" => %{
                   "execute" => _
                 }
               },
               conn
               |> get(Routes.implementation_path(conn, :show, id))
               |> validate_resp_schema(schema, "ImplementationResponse")
               |> json_response(:ok)
             )
    end

    @tag authentication: [
           user_name: "non_admin",
           permissions: [:view_published_business_concepts, :view_quality_rule]
         ]
    test "rendes only authorized links", %{conn: conn, domain: domain} do
      %{id: id} = insert(:implementation, domain_id: domain.id)

      concept_id_authorized = System.unique_integer([:positive])

      CacheHelpers.insert_concept(%{id: concept_id_authorized, domain_id: domain.id})
      CacheHelpers.insert_link(id, "implementation", "business_concept", concept_id_authorized)

      concept_id_forbidden = System.unique_integer([:positive])

      CacheHelpers.insert_concept(%{
        id: concept_id_forbidden,
        domain_id: System.unique_integer([:positive])
      })

      CacheHelpers.insert_link(id, "implementation", "business_concept", concept_id_forbidden)

      assert %{"data" => %{"links" => links}} =
               conn
               |> get(Routes.implementation_path(conn, :show, id))
               |> json_response(:ok)

      string_authorized_id = "#{concept_id_authorized}"
      assert [%{"resource_id" => ^string_authorized_id}] = links
    end

    @tag authentication: [
           user_name: "non_admin",
           permissions: [:link_implementation_business_concept, :view_quality_rule]
         ]
    test "renders link_concept action", %{conn: conn, domain: domain} do
      %{id: id} = insert(:implementation, domain_id: domain.id)

      assert %{"_actions" => actions} =
               conn
               |> get(Routes.implementation_path(conn, :show, id))
               |> json_response(:ok)

      assert %{"link_concept" => %{"method" => "POST"}} == actions
    end

    @tag authentication: [
           user_name: "non_admin",
           permissions: [:link_implementation_structure, :view_quality_rule]
         ]
    test "renders link_structure action", %{conn: conn, domain: domain} do
      %{id: id} = insert(:implementation, domain_id: domain.id)

      assert %{"_actions" => actions} =
               conn
               |> get(Routes.implementation_path(conn, :show, id))
               |> json_response(:ok)

      assert %{"link_structure" => %{"method" => "POST"}} == actions
    end

    @tag authentication: [
           user_name: "non_admin",
           permissions: [:publish_implementation, :view_quality_rule]
         ]
    test "publishers has delete actions on published implementations", %{
      conn: conn,
      domain: domain
    } do
      %{id: id} = insert(:implementation, domain_id: domain.id, status: :published)

      assert %{"_actions" => actions} =
               conn
               |> get(Routes.implementation_path(conn, :show, id))
               |> json_response(:ok)

      assert %{"delete" => %{"method" => "POST"}} == actions
    end

    ## rule implementation with actions
    for {permission_type, permissions} <- [
          {"rule implementation", @rule_implementation_permissions ++ [:manage_segments]},
          {"ruleless implementation", @imp_ruleless_permissions ++ [:manage_segments]}
        ] do
      @tag authentication: [
             user_name: "non_admin",
             permissions: permissions
           ]
      test "renders #{permission_type} actions for rule implementation", %{
        conn: conn,
        domain: domain
      } do
        %{id: id} = insert(:implementation, domain_id: domain.id)

        assert %{"_actions" => actions} =
                 conn
                 |> get(Routes.implementation_path(conn, :show, id))
                 |> json_response(:ok)

        assert %{
                 "delete" => %{"method" => "POST"},
                 "edit" => %{"method" => "POST"},
                 "manage_segments" => %{"method" => "POST"},
                 "submit" => %{"method" => "POST"}
               } == actions
      end
    end

    ## rule implementation without actions
    for {permission_type, permissions} <- [
          {"raw implementation", @imp_raw_permissions},
          {"raw ruleless implementation", @imp_raw_ruleless_permissions}
        ] do
      @tag authentication: [user_name: "non_admin", permissions: permissions]
      test "renders no actions #{permission_type} for rule implementation", %{
        conn: conn,
        domain: domain
      } do
        %{id: id} = insert(:implementation, domain_id: domain.id, segments: [])

        assert %{"_actions" => actions} =
                 conn
                 |> get(Routes.implementation_path(conn, :show, id))
                 |> json_response(:ok)

        assert Enum.empty?(actions)
      end
    end

    ## Raw rule with actions
    for {permission_type, permissions} <- [
          {"raw implementation", @imp_raw_permissions ++ [:manage_segments]},
          {"raw ruleless implementation", @imp_raw_ruleless_permissions ++ [:manage_segments]}
        ] do
      @tag authentication: [
             user_name: "non_admin",
             permissions: permissions
           ]
      test "renders #{permission_type} actions for raw implementations ", %{
        conn: conn,
        domain: domain
      } do
        %{id: rule_id} = insert(:rule, domain_id: domain.id)

        %{id: id} =
          insert(:raw_implementation,
            domain_id: domain.id,
            rule_id: rule_id,
            segments: [%{structure: %{id: 12_554}}]
          )

        assert %{"_actions" => actions} =
                 conn
                 |> get(Routes.implementation_path(conn, :show, id))
                 |> json_response(:ok)

        assert %{
                 "delete" => %{"method" => "POST"},
                 "edit" => %{"method" => "POST"},
                 "submit" => %{"method" => "POST"},
                 "manage_segments" => %{"method" => "POST"}
               } == actions
      end
    end

    ## Raw rule without actions
    for {permission_type, permissions} <- [
          {"rule implementation", @rule_implementation_permissions},
          {"ruleless implementation", @imp_ruleless_permissions}
        ] do
      @tag authentication: [user_name: "non_admin", permissions: permissions]
      test "renders no actions #{permission_type} for raw implementation", %{
        conn: conn,
        domain: domain
      } do
        rule = insert(:rule, domain_id: domain.id)
        %{id: id} = insert(:raw_implementation, rule_id: rule.id, domain_id: domain.id)

        assert %{"_actions" => actions} =
                 conn
                 |> get(Routes.implementation_path(conn, :show, id))
                 |> json_response(:ok)

        assert Enum.empty?(actions)
      end
    end

    ## ruleless with actions
    @tag authentication: [
           user_name: "non_admin",
           permissions: @imp_ruleless_permissions ++ [:manage_segments]
         ]
    test "renders ruleless implementations actions", %{conn: conn, domain: domain} do
      %{id: id} = insert(:ruleless_implementation, domain_id: domain.id)

      assert %{"_actions" => actions} =
               conn
               |> get(Routes.implementation_path(conn, :show, id))
               |> json_response(:ok)

      assert %{
               "edit" => %{"method" => "POST"},
               "delete" => %{"method" => "POST"},
               "submit" => %{"method" => "POST"},
               "manage_segments" => %{"method" => "POST"}
             } == actions
    end

    ## ruleless without actions
    for {permission_type, permissions} <- [
          {"rule implementation", @rule_implementation_permissions},
          {"raw implementation", @imp_raw_permissions},
          {"raw ruleless", @imp_raw_ruleless_permissions}
        ] do
      @tag authentication: [user_name: "non_admin", permissions: permissions]
      test "renders no actions #{permission_type} for ruleless implementation", %{
        conn: conn,
        domain: domain
      } do
        %{id: id} = insert(:ruleless_implementation, domain_id: domain.id)

        assert %{"_actions" => actions} =
                 conn
                 |> get(Routes.implementation_path(conn, :show, id))
                 |> json_response(:ok)

        assert Enum.empty?(actions)
      end
    end

    ## raw ruleless with actions
    @tag authentication: [
           user_name: "non_admin",
           permissions: @imp_raw_ruleless_permissions ++ [:manage_segments]
         ]
    test "renders actions for ruleless raw implementations", %{conn: conn, domain: domain} do
      %{id: id} =
        insert(:ruleless_implementation, domain_id: domain.id, implementation_type: "raw")

      assert %{"_actions" => actions} =
               conn
               |> get(Routes.implementation_path(conn, :show, id))
               |> json_response(:ok)

      assert %{
               "edit" => %{"method" => "POST"},
               "delete" => %{"method" => "POST"},
               "submit" => %{"method" => "POST"},
               "manage_segments" => %{"method" => "POST"}
             } == actions
    end

    ## raw ruleless without actions
    for {permission_type, permissions} <- [
          {"rule implementation", @rule_implementation_permissions},
          {"raw implementation", @imp_raw_permissions},
          {"ruleless implementation", @imp_ruleless_permissions}
        ] do
      @tag authentication: [user_name: "non_admin", permissions: permissions]
      test "renders no actions #{permission_type} for raw ruleless", %{conn: conn, domain: domain} do
        %{id: id} =
          insert(:ruleless_implementation, domain_id: domain.id, implementation_type: "raw")

        assert %{"_actions" => actions} =
                 conn
                 |> get(Routes.implementation_path(conn, :show, id))
                 |> json_response(:ok)

        assert Enum.empty?(actions)
      end
    end
  end

  describe "index" do
    @tag authentication: [role: "admin"]
    test "lists all implementations", %{conn: conn, swagger_schema: schema} do
      assert %{"data" => [_]} =
               conn
               |> get(Routes.implementation_path(conn, :index))
               |> validate_resp_schema(schema, "ImplementationsResponse")
               |> json_response(:ok)
    end

    @tag authentication: [role: "service"]
    test "service account can view implementations", %{conn: conn, swagger_schema: schema} do
      assert %{"data" => [_]} =
               conn
               |> get(Routes.implementation_path(conn, :index))
               |> validate_resp_schema(schema, "ImplementationsResponse")
               |> json_response(:ok)
    end

    @tag authentication: [role: "admin"]
    test "lists all implementations filtered by rule business_concept_id and state", %{
      conn: conn,
      swagger_schema: schema
    } do
      %{rule: rule} =
        insert(:implementation,
          implementation_key: "ri1",
          rule: build(:rule, business_concept_id: "42", active: true)
        )

      insert(:implementation, implementation_key: "ri2", rule: rule)
      insert(:implementation, implementation_key: "ri3", rule: rule)
      insert(:raw_implementation, implementation_key: "ri4", rule: rule)

      ri5 = insert(:implementation, implementation_key: "ri5")

      assert %{"data" => data} =
               conn
               |> get(Routes.implementation_path(conn, :index), %{
                 is_rule_active: true,
                 rule_business_concept_id: "42"
               })
               |> validate_resp_schema(schema, "ImplementationsResponse")
               |> json_response(:ok)

      assert length(data) == 4
      refute Enum.find(data, &(&1["id"] == ri5.id))
    end
  end

  describe "create implementation" do
    @tag authentication: [role: "admin"]
    test "renders implementation when data is valid", %{conn: conn, swagger_schema: schema} do
      rule = insert(:rule)

      creation_attrs =
        %{
          implementation_key: "a1",
          rule_id: rule.id,
          dataset: @valid_dataset,
          populations: [
            [
              %{
                operator: %{
                  name: "gt",
                  value_type: "timestamp"
                },
                structure: %{id: 12_554},
                value: [%{raw: "2019-12-02 05:35:00"}]
              },
              %{
                operator: %{
                  name: "gt",
                  value_type: "timestamp"
                },
                structure: %{id: 12_554},
                value: [%{raw: "2019-12-02 05:35:00"}]
              }
            ],
            [
              %{
                operator: %{
                  name: "gt",
                  value_type: "timestamp"
                },
                structure: %{id: 12_554},
                value: [%{raw: "2019-12-02 05:35:00"}]
              }
            ]
          ],
          validations: @validations,
          result_type: "percentage",
          minimum: 50,
          goal: 100
        }
        |> Map.Helpers.stringify_keys()

      assert %{"data" => data} =
               conn
               |> post(Routes.implementation_path(conn, :create),
                 rule_implementation: creation_attrs
               )
               |> validate_resp_schema(schema, "ImplementationResponse")
               |> json_response(:created)

      assert %{"id" => id} = data

      assert %{"data" => data} =
               conn
               |> get(Routes.implementation_path(conn, :show, id))
               |> validate_resp_schema(schema, "ImplementationResponse")
               |> json_response(:ok)

      assert rule.id == data["rule_id"]

      assert "draft" == data["status"]
      assert 1 == data["version"]

      assert equals_condition_row(
               Map.get(data, "validations"),
               Map.get(creation_attrs, "validations")
             )

      assert equals_condition_row(
               data |> Map.get("populations") |> List.first(),
               creation_attrs |> Map.get("populations") |> List.first()
             )
    end

    @tag authentication: [role: "admin"]
    test "return error when try to create more than one draft", %{
      conn: conn,
      swagger_schema: schema
    } do
      rule = insert(:rule)

      creation_attrs =
        @rule_implementation_attr
        |> Map.put(:rule_id, rule.id)
        |> Map.Helpers.stringify_keys()

      assert %{"data" => _data} =
               conn
               |> post(Routes.implementation_path(conn, :create),
                 rule_implementation: creation_attrs
               )
               |> validate_resp_schema(schema, "ImplementationResponse")
               |> json_response(:created)

      assert %{"errors" => error} =
               conn
               |> post(Routes.implementation_path(conn, :create),
                 rule_implementation: creation_attrs
               )
               |> validate_resp_schema(schema, "ImplementationResponse")
               |> json_response(:unprocessable_entity)

      assert %{"implementation_key" => ["duplicated"]} = error
    end

    @tag authentication: [role: "admin"]
    test "return error when try to create a draft with an existing implementation_key and different implementation_ref",
         %{
           conn: conn,
           swagger_schema: schema,
           claims: claims
         } do
      rule = insert(:rule)

      creation_attrs =
        @rule_implementation_attr
        |> Map.put(:rule_id, rule.id)
        |> Map.Helpers.stringify_keys()

      assert %{"data" => %{"id" => id}} =
               conn
               |> post(Routes.implementation_path(conn, :create),
                 rule_implementation: creation_attrs
               )
               |> validate_resp_schema(schema, "ImplementationResponse")
               |> json_response(:created)

      implementation = Implementations.get_implementation!(id)

      assert {:ok, %{implementation: %{id: ^id}}} =
               Implementations.update_implementation(
                 implementation,
                 %{status: :published},
                 claims
               )

      assert %{"errors" => error} =
               conn
               |> post(Routes.implementation_path(conn, :create),
                 rule_implementation: creation_attrs
               )
               |> validate_resp_schema(schema, "ImplementationResponse")
               |> json_response(:unprocessable_entity)

      assert %{"implementation_key" => ["duplicated"]} = error
    end

    @tag authentication: [role: "admin"]
    test "return success when try to create a draft on existing implementation_ref with same implementation_key",
         %{
           conn: conn,
           swagger_schema: schema,
           claims: claims
         } do
      rule = insert(:rule)

      creation_attrs =
        @rule_implementation_attr
        |> Map.put(:rule_id, rule.id)
        |> Map.Helpers.stringify_keys()

      assert %{"data" => %{"id" => id}} =
               conn
               |> post(Routes.implementation_path(conn, :create),
                 rule_implementation: creation_attrs
               )
               |> validate_resp_schema(schema, "ImplementationResponse")
               |> json_response(:created)

      %{implementation_ref: imp_ref} = implementation = Implementations.get_implementation!(id)

      assert imp_ref == id

      assert {:ok, %{implementation: %{id: ^id}}} =
               Implementations.update_implementation(
                 implementation,
                 %{status: :published, minimum: implementation.minimum - 1},
                 claims
               )

      assert %{"data" => %{"id" => new_id}} =
               conn
               |> put(Routes.implementation_path(conn, :update, implementation),
                 rule_implementation: creation_attrs
               )
               |> validate_resp_schema(schema, "ImplementationResponse")
               |> json_response(:ok)

      assert id != new_id
      assert %{implementation_ref: ^imp_ref} = Implementations.get_implementation!(new_id)
    end

    @tag authentication: [role: "admin"]
    test "return success when try to create a draft on existing implementation_ref with different implementation_key",
         %{
           conn: conn,
           swagger_schema: schema,
           claims: claims
         } do
      rule = insert(:rule)

      creation_attrs =
        @rule_implementation_attr
        |> Map.put(:rule_id, rule.id)
        |> Map.Helpers.stringify_keys()
        |> Map.drop(["status"])

      assert %{"data" => %{"id" => id}} =
               conn
               |> post(Routes.implementation_path(conn, :create),
                 rule_implementation: creation_attrs
               )
               |> validate_resp_schema(schema, "ImplementationResponse")
               |> json_response(:created)

      %{implementation_ref: imp_ref, version: 1, status: :draft} =
        implementation = Implementations.get_implementation!(id)

      assert imp_ref == id

      assert {:ok, %{implementation: %{id: ^id, version: 1, status: :published}}} =
               Implementations.update_implementation(
                 implementation,
                 %{status: :published},
                 claims
               )

      assert %{"data" => %{"id" => new_id}} =
               conn
               |> put(Routes.implementation_path(conn, :update, implementation),
                 rule_implementation: Map.put(creation_attrs, "implementation_key", "fuaah!")
               )
               |> validate_resp_schema(schema, "ImplementationResponse")
               |> json_response(:ok)

      assert id != new_id

      assert %{implementation_ref: ^imp_ref, version: 2, status: :draft} =
               Implementations.get_implementation!(new_id)
    end

    @tag authentication: [role: "admin"]
    test "return 200 but does not create a new draft when editing published implementation with same information",
         %{
           conn: conn,
           swagger_schema: schema,
           claims: claims
         } do
      rule_implementation_attr = string_params_for(:implementation) |> Map.drop(["status"])

      assert %{"data" => %{"id" => id}} =
               conn
               |> post(Routes.implementation_path(conn, :create),
                 rule_implementation: rule_implementation_attr
               )
               |> json_response(:created)

      implementation = Implementations.get_implementation(id)

      Implementations.update_implementation(
        implementation,
        %{status: :published},
        claims
      )

      assert %{
               "data" => %{"id" => ^id, "status" => "published"},
               "message" => "implementation_unchanged"
             } =
               conn
               |> put(Routes.implementation_path(conn, :update, implementation),
                 rule_implementation: rule_implementation_attr
               )
               |> validate_resp_schema(schema, "ImplementationResponse")
               |> json_response(:ok)
    end

    @tag authentication: [role: "admin"]
    test "renders implementation with segments", %{conn: conn, swagger_schema: schema} do
      rule = insert(:rule)
      structure_id = 12_554

      creation_attrs =
        @rule_implementation_attr
        |> Map.put(:rule_id, rule.id)
        |> Map.put(:segments, [%{structure: %{id: structure_id}}])
        |> Map.Helpers.stringify_keys()

      assert %{"data" => data} =
               conn
               |> post(Routes.implementation_path(conn, :create),
                 rule_implementation: creation_attrs
               )
               |> validate_resp_schema(schema, "ImplementationResponse")
               |> json_response(:created)

      assert %{"id" => id} = data

      assert %{"data" => data} =
               conn
               |> get(Routes.implementation_path(conn, :show, id))
               |> validate_resp_schema(schema, "ImplementationResponse")
               |> json_response(:ok)

      assert rule.id == data["rule_id"]
      assert %{"segments" => [%{"structure" => %{"id" => ^structure_id}}]} = data
    end

    @tag authentication: [role: "admin"]
    test "can create raw rule implementation with alias", %{
      conn: conn,
      swagger_schema: schema
    } do
      rule = insert(:rule)

      creation_attrs =
        @raw_implementation_attr
        |> Map.put(:rule_id, rule.id)
        |> Map.Helpers.stringify_keys()

      assert %{"data" => data} =
               conn
               |> post(Routes.implementation_path(conn, :create),
                 rule_implementation: creation_attrs
               )
               |> validate_resp_schema(schema, "ImplementationResponse")
               |> json_response(:created)

      assert %{
               "raw_content" => %{
                 "dataset" => "cliente c join address a on c.address_id=a.id",
                 "population" => nil,
                 "validations" => "c.city = 'MADRID'"
               }
             } = data
    end

    ## can create rule implementation
    for {permission_type, permissions} <- [
          {"rule implementation", @rule_implementation_permissions},
          {"raw implementation", @imp_ruleless_permissions}
        ] do
      @tag authentication: [user_name: "non_admin", permissions: permissions]
      test "non admin with #{permission_type} permission can create rule implementation", %{
        conn: conn,
        domain: domain
      } do
        rule = insert(:rule, domain_id: domain.id)

        creation_attrs =
          @rule_implementation_attr
          |> Map.put(:rule_id, rule.id)
          |> Map.Helpers.stringify_keys()

        assert conn
               |> post(Routes.implementation_path(conn, :create),
                 rule_implementation: creation_attrs
               )
               |> json_response(:created)
      end
    end

    ## cannot create rule implementation
    for {permission_type, permissions} <- [
          {"raw implementation", @imp_raw_permissions},
          {"raw ruleless  implementation", @imp_raw_ruleless_permissions}
        ] do
      @tag authentication: [user_name: "non_admin", permissions: permissions]
      test "non admin with #{permission_type} permission cannot create rule implementation", %{
        conn: conn,
        domain: domain
      } do
        rule = insert(:rule, domain_id: domain.id)

        creation_attrs =
          @rule_implementation_attr
          |> Map.put(:rule_id, rule.id)
          |> Map.Helpers.stringify_keys()

        assert conn
               |> post(Routes.implementation_path(conn, :create),
                 rule_implementation: creation_attrs
               )
               |> json_response(:forbidden)
      end
    end

    ## can create raw implementation
    for {permission_type, permissions} <- [
          {"raw implementation", @imp_raw_permissions},
          {"raw ruleless implementation", @imp_raw_ruleless_permissions}
        ] do
      @tag authentication: [
             user_name: "non_admin",
             permissions: permissions
           ]
      test "non admin with #{permission_type} permission can create raw implementation", %{
        conn: conn,
        domain: %{id: domain_id}
      } do
        rule = insert(:rule, domain_id: domain_id)

        creation_attrs =
          @raw_implementation_attr
          |> Map.put(:rule_id, rule.id)
          |> Map.Helpers.stringify_keys()

        assert conn
               |> post(Routes.implementation_path(conn, :create),
                 rule_implementation: creation_attrs
               )
               |> json_response(:created)
      end
    end

    ## cannot create raw implementation
    for {permission_type, permissions} <- [
          {"rule implementation", @rule_implementation_permissions},
          {"ruleless implementation", @imp_ruleless_permissions}
        ] do
      @tag authentication: [
             user_name: "non_admin",
             permissions: permissions
           ]
      test "non admin with #{permission_type} permission cannot create raw implementation", %{
        conn: conn,
        domain: %{id: domain_id}
      } do
        rule = insert(:rule, domain_id: domain_id)

        creation_attrs =
          @raw_implementation_attr
          |> Map.put(:rule_id, rule.id)
          |> Map.Helpers.stringify_keys()

        assert conn
               |> post(Routes.implementation_path(conn, :create),
                 rule_implementation: creation_attrs
               )
               |> json_response(:forbidden)
      end
    end

    ## can create rule less implementation
    @tag authentication: [
           user_name: "non_admin",
           permissions: @imp_ruleless_permissions ++ [:view_data_structure]
         ]
    test "non admin with ruleless implementation permission can create ruleless implementation",
         %{
           conn: conn,
           domain: domain,
           swagger_schema: schema
         } do
      %{id: data_structure_id} = insert(:data_structure, domain_ids: [domain.id])

      params =
        @rule_implementation_attr
        |> Map.put(:domain_id, domain.id)
        |> Map.put(:dataset, [%{structure: %{id: data_structure_id}}])
        |> Map.Helpers.stringify_keys()

      assert %{"data" => data} =
               conn
               |> post(Routes.implementation_path(conn, :create), rule_implementation: params)
               |> validate_resp_schema(schema, "ImplementationResponse")
               |> json_response(:created)

      assert %{"id" => id} = data

      assert %{"data" => data} =
               conn
               |> get(Routes.implementation_path(conn, :show, id))
               |> validate_resp_schema(schema, "ImplementationResponse")
               |> json_response(:ok)

      assert %{"data_structures" => [%{"data_structure_id" => ^data_structure_id}]} = data

      assert equals_condition_row(
               Map.get(data, "validations"),
               Map.get(params, "validations")
             )
    end

    ## cannot create ruleless implementation
    for {permission_type, permissions} <- [
          {"rule implementation", @rule_implementation_permissions},
          {"raw implementation", @imp_raw_permissions},
          {"raw ruleless implementation", @imp_raw_ruleless_permissions}
        ] do
      @tag authentication: [
             user_name: "non_admin",
             permissions: permissions
           ]
      test "non admin with #{permission_type} permission cannot create ruleless implementation",
           %{
             conn: conn,
             domain: domain
           } do
        creation_attrs =
          @rule_implementation_attr
          |> Map.put(:domain_id, domain.id)
          |> Map.Helpers.stringify_keys()

        assert conn
               |> post(Routes.implementation_path(conn, :create),
                 rule_implementation: creation_attrs
               )
               |> json_response(:forbidden)
      end
    end

    ## can create raw rulesless implementation
    @tag authentication: [
           user_name: "non_admin",
           permissions: @imp_raw_ruleless_permissions
         ]
    test "non admin with raw rulesless implementation permission can create ruleless raw implementation",
         %{
           conn: conn,
           domain: %{id: domain_id}
         } do
      creation_attrs =
        @raw_implementation_attr
        |> Map.put(:domain_id, domain_id)
        |> Map.Helpers.stringify_keys()

      assert conn
             |> post(Routes.implementation_path(conn, :create),
               rule_implementation: creation_attrs
             )
             |> json_response(:created)
    end

    ## cannot create raw ruleless implementation
    for {permission_type, permissions} <- [
          {"rule implementation", @rule_implementation_permissions},
          {"ruleless implementation", @imp_ruleless_permissions},
          {"raw implementation", @imp_raw_permissions}
        ] do
      @tag authentication: [
             user_name: "non_admin",
             permissions: permissions
           ]
      test "non admin with #{permission_type} permission cannot create ruleless raw implementation",
           %{
             conn: conn,
             domain: domain
           } do
        creation_attrs =
          @raw_implementation_attr
          |> Map.put(:domain_id, domain.id)
          |> Map.Helpers.stringify_keys()

        assert conn
               |> post(Routes.implementation_path(conn, :create),
                 rule_implementation: creation_attrs
               )
               |> json_response(:forbidden)
      end
    end

    ## segments
    @tag authentication: [role: "non_admin", permissions: @rule_implementation_permissions]
    test "non admin without manage segments permission can't create implementation with segments",
         %{
           conn: conn,
           domain: %{id: domain_id}
         } do
      rule = insert(:rule, domain_id: domain_id)

      creation_attrs =
        @rule_implementation_attr
        |> Map.put(:segments, [%{structure: %{id: 12_554}}])
        |> Map.put(:rule_id, rule.id)
        |> Map.Helpers.stringify_keys()

      assert conn
             |> post(Routes.implementation_path(conn, :create),
               rule_implementation: creation_attrs
             )
             |> json_response(:forbidden)
    end

    @tag authentication: [role: "non_admin", permissions: @rule_implementation_permissions]
    test "non admin without manage segments permission can create implementation without segments",
         %{
           conn: conn,
           domain: %{id: domain_id}
         } do
      rule = insert(:rule, domain_id: domain_id)

      creation_attrs =
        @rule_implementation_attr
        |> Map.put(:rule_id, rule.id)
        |> Map.Helpers.stringify_keys()

      assert conn
             |> post(Routes.implementation_path(conn, :create),
               rule_implementation: creation_attrs
             )
             |> json_response(:created)
    end

    @tag authentication: [
           role: "non_admin",
           permissions: @rule_implementation_permissions ++ [:manage_segments]
         ]
    test "non admin with manage segments permission can create implementation with segments",
         %{
           conn: conn,
           domain: %{id: domain_id}
         } do
      rule = insert(:rule, domain_id: domain_id)

      creation_attrs =
        @rule_implementation_attr
        |> Map.put(:rule_id, rule.id)
        |> Map.put(:segments, [%{structure: %{id: 12_554}}])
        |> Map.Helpers.stringify_keys()

      assert conn
             |> post(Routes.implementation_path(conn, :create),
               rule_implementation: creation_attrs
             )
             |> json_response(:created)
    end

    @tag authentication: [role: "admin"]
    test "generates identifier on template", %{conn: conn} do
      %{name: template_name} = CacheHelpers.insert_template(@identifier_template)
      rule = insert(:rule)

      creation_attrs =
        @raw_implementation_attr
        |> Map.put(:rule_id, rule.id)
        |> Map.put(:df_name, template_name)
        |> Map.put(:df_content, %{identifier_field: ""})
        |> Map.Helpers.stringify_keys()

      assert %{"data" => %{"df_content" => %{"identifier_field" => identifier_value}}} =
               conn
               |> post(Routes.implementation_path(conn, :create),
                 rule_implementation: creation_attrs
               )
               |> json_response(:created)

      refute is_nil(identifier_value) or identifier_value == ""
    end

    @tag authentication: [role: "admin"]
    test "errors trying to create raw rule implementation without source_id", %{
      conn: conn,
      swagger_schema: schema
    } do
      rule = insert(:rule)

      creation_attrs =
        %{
          implementation_key: "a1",
          implementation_type: "raw",
          rule_id: rule.id,
          raw_content: %{
            dataset: "cliente c join address a on c.address_id=a.id",
            population: nil,
            validations: "c.city = 'MADRID'"
          }
        }
        |> Map.Helpers.stringify_keys()

      assert %{"errors" => errors} =
               conn
               |> post(Routes.implementation_path(conn, :create),
                 rule_implementation: creation_attrs
               )
               |> validate_resp_schema(schema, "ImplementationResponse")
               |> json_response(:unprocessable_entity)

      assert %{
               "raw_content" => %{
                 "source_id" => ["can't be blank"]
               }
             } = errors
    end

    @tag authentication: [role: "admin"]
    test "renders errors when data is invalid", %{conn: conn} do
      rule = insert(:rule)

      params =
        string_params_for(:implementation,
          rule_id: rule.id,
          dataset: [
            %{id: 14_080},
            %{id: 3233, right: %{id: "a"}, left: %{id: 22}, join_type: "inner"}
          ]
        )

      assert %{"errors" => _errors} =
               conn
               |> post(Routes.implementation_path(conn, :create), rule_implementation: params)
               |> json_response(:unprocessable_entity)
    end

    @tag authentication: [role: "admin"]
    test "renders errors when validations is invalid", %{conn: conn} do
      rule = insert(:rule)

      params =
        string_params_for(:implementation,
          rule_id: rule.id,
          dataset: [
            %{structure: %{id: 14_080}},
            %{
              structure: %{id: 3233},
              clauses: [%{right: %{id: 1}, left: %{id: 22}}],
              join_type: "inner"
            }
          ],
          validations: [
            %{
              structure: %{id: 2},
              operator: %{name: "eq", value_type: "number"},
              value: [%{raw: "4"}]
            }
          ]
        )

      assert %{"errors" => _errors} =
               conn
               |> post(Routes.implementation_path(conn, :create), rule_implementation: params)
               |> json_response(:unprocessable_entity)
    end

    @tag authentication: [role: "admin"]
    test "renders errors when implementation result type is numeric and goal is higher than minimum",
         %{conn: conn} do
      domain_id = System.unique_integer([:positive])
      rule = insert(:rule, domain_id: domain_id)

      params =
        string_params_for(:implementation,
          rule_id: rule.id,
          minimum: 5,
          goal: 10,
          result_type: "errors_number"
        )

      assert %{"errors" => errors} =
               conn
               |> post(Routes.implementation_path(conn, :create), rule_implementation: params)
               |> json_response(:unprocessable_entity)

      assert %{"minimum" => ["must.be.greater.than.or.equal.to.goal"]} = errors
    end

    @tag authentication: [role: "admin"]
    test "renders errors when implementation result type is percentage and goal is lower than minimum",
         %{conn: conn} do
      %{id: rule_id} = insert(:rule)

      params =
        string_params_for(:implementation,
          rule_id: rule_id,
          result_type: "percentage",
          minimum: 50,
          goal: 10
        )

      assert %{"errors" => errors} =
               conn
               |> post(Routes.implementation_path(conn, :create), rule_implementation: params)
               |> json_response(:unprocessable_entity)

      assert %{"goal" => ["must.be.greater.than.or.equal.to.minimum"]} = errors
    end
  end

  describe "update implementation" do
    @tag authentication: [role: "admin"]
    test "renders implementation when data is valid", %{conn: conn, swagger_schema: schema} do
      %{implementation_ref: ref} = implementation = insert(:implementation)

      params =
        %{populations: @populations}
        |> Map.Helpers.stringify_keys()

      assert %{"data" => data} =
               conn
               |> put(Routes.implementation_path(conn, :update, implementation),
                 rule_implementation: params
               )
               |> validate_resp_schema(schema, "ImplementationResponse")
               |> json_response(:ok)

      assert %{"id" => id} = data

      assert %{implementation_ref: ^ref} = TdDq.Implementations.get_implementation!(id)

      assert %{"data" => data} =
               conn
               |> get(Routes.implementation_path(conn, :show, id))
               |> validate_resp_schema(schema, "ImplementationResponse")
               |> json_response(:ok)

      assert implementation.rule_id == data["rule_id"]

      assert length(implementation.validations) == length(data["validations"])

      assert equals_condition_row(
               data |> Map.get("populations") |> List.first(),
               params |> Map.get("populations") |> List.first()
             )
    end

    @tag authentication: [role: "admin"]
    test "create new implementation with same implementation_ref when previous one has published status",
         %{conn: conn, swagger_schema: schema} do
      %{implementation_ref: ref, id: published_id} =
        implementation = insert(:implementation, status: :published)

      assert ref != nil

      params = %{goal: "40", dataset: @valid_dataset, minimum: "3", validations: @validations}

      assert %{"data" => data} =
               conn
               |> put(Routes.implementation_path(conn, :update, implementation),
                 rule_implementation: params
               )
               |> validate_resp_schema(schema, "ImplementationResponse")
               |> json_response(:ok)

      assert %{"id" => id} = data

      assert id != published_id
      assert %{implementation_ref: ^ref} = TdDq.Implementations.get_implementation!(id)
    end

    @tag authentication: [user_name: "non_admin"]
    test "user without permissions cannot update", %{conn: conn} do
      implementation = insert(:implementation)

      params =
        %{populations: @populations}
        |> Map.Helpers.stringify_keys()

      assert conn
             |> put(Routes.implementation_path(conn, :update, implementation),
               rule_implementation: params
             )
             |> json_response(:forbidden)
    end

    ## can update rule implementation
    for {permission_type, permissions} <- [
          {"rule implementation", @rule_implementation_permissions ++ [:manage_segments]},
          {"ruleless implementation", @imp_ruleless_permissions ++ [:manage_segments]}
        ] do
      @tag authentication: [
             user_name: "non_admin",
             permissions: permissions
           ]
      test "user with #{permission_type} permissions can update rule implementation", %{
        conn: conn,
        domain: %{id: domain_id}
      } do
        %{id: rule_id} = insert(:rule, domain_id: domain_id)
        implementation = insert(:implementation, rule_id: rule_id, domain_id: domain_id)
        structure_id = 12_554

        params =
          %{
            segments: [%{structure: %{id: structure_id}}],
            validations: @validations,
            populations: @populations
          }
          |> Map.Helpers.stringify_keys()

        assert %{"data" => data} =
                 conn
                 |> put(Routes.implementation_path(conn, :update, implementation),
                   rule_implementation: params
                 )
                 |> json_response(:ok)

        assert %{"segments" => [%{"structure" => %{"id" => ^structure_id}}]} = data
      end
    end

    ## cannot update rule implementation
    for {permission_type, permissions} <- [
          {"raw implementation", @imp_raw_permissions},
          {"raw ruleless implementation", @imp_raw_ruleless_permissions}
        ] do
      @tag authentication: [user_name: "non_admin", permissions: permissions]
      test "user with #{permission_type} permissions cannot update rule implementation", %{
        conn: conn,
        domain: %{id: domain_id}
      } do
        %{id: rule_id} = insert(:rule, domain_id: domain_id)
        implementation = insert(:implementation, rule_id: rule_id, domain_id: domain_id)

        params =
          %{validations: @validations, populations: @populations}
          |> Map.Helpers.stringify_keys()

        assert conn
               |> put(Routes.implementation_path(conn, :update, implementation),
                 rule_implementation: params
               )
               |> json_response(:forbidden)
      end
    end

    ### can update raw implementation
    for {permission_type, permissions} <- [
          {"raw implementation", @imp_raw_permissions},
          {"raw ruleless implementation", @imp_raw_ruleless_permissions}
        ] do
      @tag authentication: [user_name: "non_admin", permissions: permissions]
      test "user with #{permission_type} permissions can update raw implementation", %{
        conn: conn,
        domain: %{id: domain_id}
      } do
        %{id: rule_id} = insert(:rule, domain_id: domain_id)
        implementation = insert(:raw_implementation, rule_id: rule_id, domain_id: domain_id)

        params =
          %{validations: @validations, populations: @populations}
          |> Map.Helpers.stringify_keys()

        assert %{"data" => _data} =
                 conn
                 |> put(Routes.implementation_path(conn, :update, implementation),
                   rule_implementation: params
                 )
                 |> json_response(:ok)
      end
    end

    ## cannot update raw implementation
    for {permission_type, permissions} <- [
          {"rule implementation", @rule_implementation_permissions},
          {"rule less implementation", @imp_ruleless_permissions}
        ] do
      @tag authentication: [user_name: "non_admin", permissions: permissions]
      test "user with #{permission_type} permissions cannot update raw implementation", %{
        conn: conn,
        domain: %{id: domain_id}
      } do
        %{id: rule_id} = insert(:rule, domain_id: domain_id)
        implementation = insert(:raw_implementation, rule_id: rule_id, domain_id: domain_id)

        params =
          %{validations: @validations, populations: @populations}
          |> Map.Helpers.stringify_keys()

        assert conn
               |> put(Routes.implementation_path(conn, :update, implementation),
                 rule_implementation: params
               )
               |> json_response(:forbidden)
      end
    end

    ## can update ruleless implementation
    @tag authentication: [user_name: "non_admin", permissions: @imp_ruleless_permissions]
    test "user with ruleless implementation permissions can update ruleless implementation", %{
      conn: conn,
      domain: %{id: domain_id}
    } do
      implementation = insert(:ruleless_implementation, domain_id: domain_id)

      params =
        %{validations: @validations, populations: @populations}
        |> Map.Helpers.stringify_keys()

      assert %{"data" => _data} =
               conn
               |> put(Routes.implementation_path(conn, :update, implementation),
                 rule_implementation: params
               )
               |> json_response(:ok)
    end

    ## cannot update ruleless implementation
    for {permission_type, permissions} <- [
          {"rule implementation", @rule_implementation_permissions},
          {"raw implementation", @imp_raw_permissions},
          {"raw ruleless implementation", @imp_raw_ruleless_permissions}
        ] do
      @tag authentication: [user_name: "non_admin", permissions: permissions]
      test "user with #{permission_type} permissions cannot update ruleless implementation", %{
        conn: conn,
        domain: %{id: domain_id}
      } do
        implementation = insert(:ruleless_implementation, domain_id: domain_id)

        params =
          %{validations: @validations, populations: @populations}
          |> Map.Helpers.stringify_keys()

        assert conn
               |> put(Routes.implementation_path(conn, :update, implementation),
                 rule_implementation: params
               )
               |> json_response(:forbidden)
      end
    end

    ## can update raw ruleless implementation
    @tag authentication: [
           user_name: "non_admin",
           permissions: @imp_raw_ruleless_permissions ++ [:manage_segments]
         ]
    test "user with raw ruleless permissions can update raw ruleless implementation", %{
      conn: conn,
      domain: %{id: domain_id}
    } do
      implementation = insert(:raw_implementation, domain_id: domain_id, rule_id: nil)

      params =
        %{
          segments: [%{structure: %{id: 12_554}}],
          validations: @validations,
          populations: @populations
        }
        |> Map.Helpers.stringify_keys()

      assert %{"data" => _data} =
               conn
               |> put(Routes.implementation_path(conn, :update, implementation),
                 rule_implementation: params
               )
               |> json_response(:ok)
    end

    ## cannot update raw ruleless implementation
    for {permission_type, permissions} <- [
          {"rule implementation", @rule_implementation_permissions},
          {"raw implementation", @imp_raw_permissions},
          {"ruleless implementation", @imp_ruleless_permissions}
        ] do
      @tag authentication: [user_name: "non_admin", permissions: permissions]
      test "user with #{permission_type} permissions cannot update raw ruleless implementation",
           %{
             conn: conn,
             domain: %{id: domain_id}
           } do
        implementation = insert(:raw_implementation, domain_id: domain_id, rule_id: nil)

        params =
          %{validations: @validations, populations: @populations}
          |> Map.Helpers.stringify_keys()

        assert conn
               |> put(Routes.implementation_path(conn, :update, implementation),
                 rule_implementation: params
               )
               |> json_response(:forbidden)
      end
    end

    @tag authentication: [
           user_name: "non_admin",
           permissions: [
             :manage_quality_rule_implementations
           ]
         ]
    test "user with permissions can not update different dratf status", %{
      conn: conn,
      domain: %{id: domain_id}
    } do
      %{id: rule_id} = insert(:rule, domain_id: domain_id)

      implementation =
        insert(:implementation,
          rule_id: rule_id,
          domain_id: domain_id,
          segments: [],
          status: "pending_approval"
        )

      params =
        %{validations: @validations}
        |> Map.Helpers.stringify_keys()

      assert %{"errors" => error} =
               conn
               |> put(Routes.implementation_path(conn, :update, implementation),
                 rule_implementation: params
               )
               |> json_response(:forbidden)

      assert %{"detail" => "Forbidden"} = error
    end

    @tag authentication: [
           role: "non_admin",
           permissions: @rule_implementation_permissions
         ]
    test "non admin without manage segments permission can't update implementation with segments",
         %{
           conn: conn,
           domain: %{id: domain_id}
         } do
      %{id: rule_id} = insert(:rule, domain_id: domain_id)
      implementation = insert(:implementation, rule_id: rule_id, domain_id: domain_id)

      params =
        %{
          validations: @validations,
          populations: @populations
        }
        |> Map.Helpers.stringify_keys()

      assert conn
             |> put(Routes.implementation_path(conn, :update, implementation),
               rule_implementation: params
             )
             |> json_response(:forbidden)
    end

    @tag authentication: [
           role: "non_admin",
           permissions: @rule_implementation_permissions
         ]
    test "non admin without manage segments permission can update implementation without segments",
         %{
           conn: conn,
           domain: %{id: domain_id}
         } do
      %{id: rule_id} = insert(:rule, domain_id: domain_id)

      implementation =
        insert(:implementation, rule_id: rule_id, domain_id: domain_id, segments: [])

      params =
        %{
          validations: @validations,
          populations: @populations
        }
        |> Map.Helpers.stringify_keys()

      assert conn
             |> put(Routes.implementation_path(conn, :update, implementation),
               rule_implementation: params
             )
             |> json_response(:ok)
    end

    @tag authentication: [
           role: "non_admin",
           permissions: @rule_implementation_permissions
         ]
    test "non admin without manage segments permission can't update implementation adding segments",
         %{
           conn: conn,
           domain: %{id: domain_id}
         } do
      %{id: rule_id} = insert(:rule, domain_id: domain_id)

      implementation =
        insert(:implementation, rule_id: rule_id, domain_id: domain_id, segments: [])

      params =
        %{
          segments: [%{structure: %{id: 12_554}}],
          validations: @validations,
          populations: @populations
        }
        |> Map.Helpers.stringify_keys()

      assert conn
             |> put(Routes.implementation_path(conn, :update, implementation),
               rule_implementation: params
             )
             |> json_response(:forbidden)
    end

    @tag authentication: [
           role: "non_admin",
           permissions: [
             :manage_quality_rule_implementations,
             :manage_segments
           ]
         ]
    test "non admin with manage segments permission can update implementation with segments",
         %{
           conn: conn,
           domain: %{id: domain_id}
         } do
      %{id: rule_id} = insert(:rule, domain_id: domain_id)
      implementation = insert(:implementation, rule_id: rule_id, domain_id: domain_id)

      params =
        %{
          validations: @validations,
          populations: @populations
        }
        |> Map.Helpers.stringify_keys()

      assert conn
             |> put(Routes.implementation_path(conn, :update, implementation),
               rule_implementation: params
             )
             |> json_response(:ok)
    end

    @tag authentication: [
           role: "non_admin",
           permissions: [
             :manage_quality_rule_implementations,
             :manage_segments
           ]
         ]
    test "non admin with manage segments permission can update implementation adding segments",
         %{
           conn: conn,
           domain: %{id: domain_id}
         } do
      %{id: rule_id} = insert(:rule, domain_id: domain_id)

      implementation =
        insert(:implementation, rule_id: rule_id, domain_id: domain_id, segments: [])

      params =
        %{
          segments: [%{structure: %{id: 12_554}}],
          validations: @validations,
          populations: @populations
        }
        |> Map.Helpers.stringify_keys()

      assert conn
             |> put(Routes.implementation_path(conn, :update, implementation),
               rule_implementation: params
             )
             |> json_response(:ok)
    end

    @tag authentication: [role: "admin"]
    test "can update rule implementation implementation key", %{
      conn: conn,
      swagger_schema: schema
    } do
      implementation = insert(:implementation)
      update_attrs = %{implementation_key: "updated"}

      assert %{"data" => data} =
               conn
               |> put(Routes.implementation_path(conn, :update, implementation),
                 rule_implementation: update_attrs
               )
               |> validate_resp_schema(schema, "ImplementationResponse")
               |> json_response(:ok)

      assert %{"id" => id} = data

      assert %{"data" => data} =
               conn
               |> get(Routes.implementation_path(conn, :show, id))
               |> validate_resp_schema(schema, "ImplementationResponse")
               |> json_response(:ok)

      assert implementation.rule_id == data["rule_id"]
    end

    @tag authentication: [role: "admin"]
    test "renders errors when data is invalid", %{conn: conn} do
      implementation = insert(:implementation)

      update_attrs = %{
        populations: [
          %{
            population: [
              %{
                value: [%{id: 2}],
                operator: %{
                  name: "eq",
                  value_type: "number"
                },
                structure: %{id2: 6311}
              }
            ]
          }
        ]
      }

      assert %{"errors" => _errors} =
               conn
               |> put(Routes.implementation_path(conn, :update, implementation),
                 rule_implementation: update_attrs
               )
               |> json_response(:unprocessable_entity)
    end

    @tag authentication: [role: "admin"]
    test "accepts base64 encoded raw_content", %{conn: conn, swagger_schema: schema} do
      %{id: id} = insert(:raw_implementation, domain_id: 123)

      params = %{
        "rule_implementation" => %{
          "raw_content" => %{
            "source_id" => 123,
            "dataset" => Base.encode64("Some dataset"),
            "population" => "Not encoded",
            "validations" => Base.encode64("Encoded population")
          }
        }
      }

      assert %{"data" => data} =
               conn
               |> patch(Routes.implementation_path(conn, :update, id, params))
               |> validate_resp_schema(schema, "ImplementationResponse")
               |> json_response(:ok)

      assert %{
               "raw_content" => %{
                 "dataset" => "Some dataset",
                 "population" => "Not encoded",
                 "validations" => "Encoded population"
               }
             } = data
    end

    @tag authentication: [role: "admin"]
    test "updating implementation will update the cache if implementation is linked", %{
      conn: conn
    } do
      %{id: id} = implementation = insert(:implementation)
      update_attrs = %{goal: "40"}

      CacheHelpers.put_implementation(implementation)
      %{id: concept_id} = CacheHelpers.insert_concept()
      CacheHelpers.insert_link(id, "implementation", "business_concept", concept_id)

      assert {:ok, %{id: ^id, deleted_at: nil}} = CacheHelpers.get_implementation(id)

      assert conn
             |> put(Routes.implementation_path(conn, :update, implementation),
               rule_implementation: update_attrs
             )
             |> json_response(:ok)

      assert {:ok, %{id: ^id, goal: 40.0}} = CacheHelpers.get_implementation(id)
    end

    @tag authentication: [role: "admin"]
    test "updating implementation will not update the cache if implementation is not linked", %{
      conn: conn
    } do
      %{id: id} = implementation = insert(:implementation)
      update_attrs = %{goal: "40"}

      CacheHelpers.put_implementation(implementation)
      assert {:ok, %{id: ^id, deleted_at: nil}} = CacheHelpers.get_implementation(id)

      assert conn
             |> put(Routes.implementation_path(conn, :update, implementation),
               rule_implementation: update_attrs
             )
             |> json_response(:ok)

      assert {:ok, %{id: ^id, goal: 30.0}} = CacheHelpers.get_implementation(id)
    end
  end

  describe "delete implementation" do
    ## can delete rule implementation
    for {permission_type, permissions} <- [
          {"rule implementation", @rule_implementation_permissions ++ [:manage_segments]},
          {"ruleless implementation", @imp_ruleless_permissions ++ [:manage_segments]}
        ] do
      @tag authentication: [
             user_name: "non_admin",
             permissions: permissions
           ]
      test "user with #{permission_type} permissions can delete rule implementation", %{
        conn: conn,
        domain: %{id: domain_id}
      } do
        rule = insert(:rule, domain_id: domain_id)
        implementation = insert(:implementation, rule_id: rule.id, domain_id: domain_id)

        assert conn
               |> delete(Routes.implementation_path(conn, :delete, implementation))
               |> response(:no_content)

        assert_error_sent(:not_found, fn ->
          get(conn, Routes.implementation_path(conn, :show, implementation))
        end)
      end
    end

    ## cannot delete rule implementation
    for {permission_type, permissions} <- [
          {"raw implementation", @imp_raw_permissions},
          {"raw ruleless implementation", @imp_raw_ruleless_permissions}
        ] do
      @tag authentication: [user_name: "non_admin", permissions: permissions]
      test "user without #{permission_type} permissions cannot delete rule implementation", %{
        conn: conn,
        domain: %{id: domain_id}
      } do
        rule = insert(:rule, domain_id: domain_id)

        implementation =
          insert(:implementation, rule_id: rule.id, domain_id: domain_id, segments: [])

        assert conn
               |> delete(Routes.implementation_path(conn, :delete, implementation))
               |> response(:forbidden)
      end
    end

    ## can delete raw implementation
    for {permission_type, permissions} <- [
          {"raw implementation", @imp_raw_permissions},
          {"raw ruleless implementation", @imp_raw_ruleless_permissions}
        ] do
      @tag authentication: [
             user_name: "non_admin",
             permissions: permissions
           ]
      test "user with #{permission_type} permissions can delete raw implementation", %{
        conn: conn,
        domain: %{id: domain_id}
      } do
        rule = insert(:rule, domain_id: domain_id)
        implementation = insert(:raw_implementation, domain_id: domain_id, rule_id: rule.id)

        assert conn
               |> delete(Routes.implementation_path(conn, :delete, implementation))
               |> response(:no_content)

        assert_error_sent(:not_found, fn ->
          get(conn, Routes.implementation_path(conn, :show, implementation))
        end)
      end
    end

    ## cannot delete raw implementation
    for {permission_type, permissions} <- [
          {"rule implementation", @rule_implementation_permissions},
          {"ruleless implementation", @imp_ruleless_permissions}
        ] do
      @tag authentication: [user_name: "non_admin", permissions: permissions]
      test "user without #{permission_type} permissions cannot delete raw implementation", %{
        conn: conn,
        domain: domain
      } do
        rule = insert(:rule, domain_id: domain.id)
        implementation = insert(:raw_implementation, rule_id: rule.id, domain_id: domain.id)

        assert conn
               |> delete(Routes.implementation_path(conn, :delete, implementation))
               |> response(:forbidden)
      end
    end

    ## can delete ruleless implementation
    @tag authentication: [
           user_name: "non_admin",
           permissions: @imp_ruleless_permissions
         ]
    test "user with ruleless implementation permissions can delete ruleless implementation", %{
      conn: conn,
      domain: %{id: domain_id}
    } do
      implementation = insert(:ruleless_implementation, domain_id: domain_id)

      assert conn
             |> delete(Routes.implementation_path(conn, :delete, implementation))
             |> response(:no_content)

      assert_error_sent(:not_found, fn ->
        get(conn, Routes.implementation_path(conn, :show, implementation))
      end)
    end

    ## cannot delete ruleless implementation
    for {permission_type, permissions} <- [
          {"rule implementation", @rule_implementation_permissions},
          {"raw implementation", @imp_raw_permissions},
          {"raw ruleless implementation", @imp_raw_ruleless_permissions}
        ] do
      @tag authentication: [user_name: "non_admin", permissions: permissions]
      test "user without #{permission_type} permissions cannot delete ruleless implementation", %{
        conn: conn,
        domain: domain
      } do
        implementation = insert(:ruleless_implementation, domain_id: domain.id)

        assert conn
               |> delete(Routes.implementation_path(conn, :delete, implementation))
               |> response(:forbidden)
      end
    end

    ## can delelete raw ruleless implementation
    @tag authentication: [
           user_name: "non_admin",
           permissions: @imp_raw_ruleless_permissions
         ]
    test "user with raw ruleless implementation permissions can delete raw ruleless implementation",
         %{
           conn: conn,
           domain: %{id: domain_id}
         } do
      implementation =
        insert(:ruleless_implementation, domain_id: domain_id, implementation_type: "raw")

      assert conn
             |> delete(Routes.implementation_path(conn, :delete, implementation))
             |> response(:no_content)

      assert_error_sent(:not_found, fn ->
        get(conn, Routes.implementation_path(conn, :show, implementation))
      end)
    end

    ## cannot delete raw ruleless implementation
    for {permission_type, permissions} <- [
          {"rule implementation", @rule_implementation_permissions},
          {"raw implementation", @imp_raw_permissions},
          {"ruleless implementation", @imp_ruleless_permissions}
        ] do
      @tag authentication: [user_name: "non_admin", permissions: permissions]
      test "user without #{permission_type} permissions cannot delete raw ruleless implementation",
           %{
             conn: conn,
             domain: domain
           } do
        implementation =
          insert(:ruleless_implementation, domain_id: domain.id, implementation_type: "raw")

        assert conn
               |> delete(Routes.implementation_path(conn, :delete, implementation))
               |> response(:forbidden)
      end
    end
  end

  describe "search_rule_implementations" do
    for role <- ["admin", "service"] do
      @tag authentication: [role: "service"]
      test "#{role} account can search implementations", %{
        conn: conn,
        swagger_schema: schema
      } do
        %{id: id, implementation_ref: ref} = implementation = insert(:implementation)

        ElasticsearchMock
        |> expect(:request, fn
          _, :post, "/implementations/_search", %{from: 0, size: 1000, query: query}, [] ->
            assert query == %{
                     bool: %{
                       filter: [%{term: %{"status" => "published"}}, %{term: %{"rule_id" => 123}}],
                       must_not: %{exists: %{field: "deleted_at"}}
                     }
                   }

            SearchHelpers.hits_response([implementation])
        end)

        assert %{"data" => data} =
                 conn
                 |> post(Routes.rule_implementation_path(conn, :search_rule_implementations, 123))
                 |> validate_resp_schema(schema, "ImplementationsResponse")
                 |> json_response(:ok)

        assert [%{"id" => ^id, "implementation_ref" => ^ref}] = data
      end
    end

    @tag authentication: [role: "admin"]
    test "search implementations with raw_content", %{
      conn: conn,
      swagger_schema: schema
    } do
      %{rule_id: rule_id} = implementation = insert(:raw_implementation)

      ElasticsearchMock
      |> expect(:request, fn
        _, :post, "/implementations/_search", %{from: 0, size: 1000, query: _}, [] ->
          SearchHelpers.hits_response([implementation])
      end)

      assert %{"data" => data} =
               conn
               |> post(
                 Routes.rule_implementation_path(conn, :search_rule_implementations, rule_id)
               )
               |> validate_resp_schema(schema, "ImplementationsResponse")
               |> json_response(:ok)

      assert [%{"rule_id" => ^rule_id}] = data
    end

    @tag authentication: [role: "admin"]
    test "lists all deleted implementations of a rule", %{conn: conn, swagger_schema: schema} do
      %{id: id} = implementation = insert(:implementation, deleted_at: DateTime.utc_now())

      ElasticsearchMock
      |> expect(:request, fn
        _, :post, "/implementations/_search", %{from: 0, size: 1000, query: query}, [] ->
          assert query == %{
                   bool: %{
                     filter: [
                       %{exists: %{field: "deleted_at"}},
                       %{term: %{"rule_id" => 123}}
                     ]
                   }
                 }

          SearchHelpers.hits_response([implementation])
      end)

      assert %{"data" => data} =
               conn
               |> post(
                 Routes.rule_implementation_path(conn, :search_rule_implementations, 123,
                   status: "deleted"
                 )
               )
               |> validate_resp_schema(schema, "ImplementationsResponse")
               |> json_response(:ok)

      assert [%{"id" => ^id}] = data
    end
  end

  describe "csv" do
    setup do
      result =
        build(:rule_result, records: 3245, result_type: "percentage", errors: 123, result: 0)

      implementations = [
        insert(:implementation,
          results: [result],
          df_content: %{"some_first_field" => "some_first_value"}
        ),
        insert(:implementation, df_content: %{"some_second_field" => "some_value"}),
        insert(:implementation, df_content: %{"some_second_field" => "some_second_value"})
      ]

      [implementations: implementations, result: result]
    end

    @tag authentication: [role: "admin"]
    test "download all implementations as csv", %{
      conn: conn,
      implementation: previous_implementation,
      implementations: new_implementations
    } do
      ElasticsearchMock
      |> expect(:request, fn
        _,
        :post,
        "/implementations/_search",
        %{from: 0, size: 10_000, sort: sort, query: query},
        [] ->
          assert query == %{
                   bool: %{
                     filter: %{match_all: %{}},
                     must_not: %{exists: %{field: "deleted_at"}}
                   }
                 }

          assert sort == ["_score", "implementation_key.raw"]

          SearchHelpers.hits_response([previous_implementation | new_implementations])
      end)

      [
        %{implementation_key: key_0, rule: %{name: name_0}, inserted_at: inserted_at_0},
        %{
          implementation_key: key_1,
          rule: %{name: name_1},
          results: [%{records: records_1, errors: errors_1}],
          inserted_at: inserted_at_1
        },
        %{implementation_key: key_2, rule: %{name: name_2}, inserted_at: inserted_at_2},
        %{implementation_key: key_3, rule: %{name: name_3}, inserted_at: inserted_at_3}
      ] = [previous_implementation | new_implementations]

      assert %{resp_body: body} = post(conn, Routes.implementation_path(conn, :csv, %{}))

      time_zone = Application.get_env(:td_dd, :time_zone)

      ts_0 =
        DateTime.to_string(inserted_at_0)
        |> TdDd.Helpers.shift_zone(time_zone)
        |> String.replace("+", "\\+")

      ts_1 =
        DateTime.to_string(inserted_at_1)
        |> TdDd.Helpers.shift_zone(time_zone)
        |> String.replace("+", "\\+")

      ts_2 =
        DateTime.to_string(inserted_at_2)
        |> TdDd.Helpers.shift_zone(time_zone)
        |> String.replace("+", "\\+")

      ts_3 =
        DateTime.to_string(inserted_at_3)
        |> TdDd.Helpers.shift_zone(time_zone)
        |> String.replace("+", "\\+")

      for regex <- [
            # credo:disable-for-lines:5 Credo.Check.Readability.MaxLineLength
            "implementation_key;implementation_type;executable;rule;rule_template;implementation_template;goal;minimum;business_concept;last_execution_at;records;errors;result;execution;inserted_at;dataset_external_id_1;validation_field_1\r",
            ~r/#{key_0};default;[\w+.]+;#{name_0};;;\d*\.?\d*;\d*\.?\d*;;;;;;;#{ts_0};;;\r/,
            ~r/#{key_1};default;[\w+.]+;#{name_1};;;\d*\.?\d*;\d*\.?\d*;;[[:ascii:]]+;#{records_1};#{errors_1};\d*\.?\d*;[\w+.]+;#{ts_1};;;\r/,
            ~r/#{key_2};default;[\w+.]+;#{name_2};;;\d*\.?\d*;\d*\.?\d*;;;;;;;#{ts_2};;;\r/,
            ~r/#{key_3};default;[\w+.]+;#{name_3};;;\d*\.?\d*;\d*\.?\d*;;;;;;;#{ts_3};;;\r/
          ] do
        assert body =~ regex
      end
    end
  end

  defp equals_condition_row(population_response, population_update) do
    population_response
    |> Enum.with_index()
    |> Enum.all?(fn {response_population, index} ->
      update_attrs_population = Enum.at(population_update, index)
      assert update_attrs_population["operator"] == response_population["operator"]
      assert update_attrs_population["structure"]["id"] == response_population["structure"]["id"]
      values_index = Enum.with_index(update_attrs_population |> Map.get("value"))

      Enum.map(values_index, fn {value, index} ->
        assert value |> Map.get("id") ==
                 response_population |> Map.get("value") |> Enum.at(index) |> Map.get("id")
      end)
    end)
  end
end
