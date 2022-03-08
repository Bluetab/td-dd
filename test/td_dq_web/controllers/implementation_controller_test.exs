defmodule TdDqWeb.ImplementationControllerTest do
  use TdDqWeb.ConnCase
  use PhoenixSwagger.SchemaTest, "priv/static/swagger_dq.json"

  alias TdCache.ConceptCache

  @valid_dataset [
    %{structure: %{id: 14_080}},
    %{clauses: [%{left: %{id: 14_863}, right: %{id: 4028}}], structure: %{id: 3233}}
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

  setup_all do
    start_supervised(TdDd.Search.MockIndexWorker)
    start_supervised(TdDq.Cache.RuleLoader)
    :ok
  end

  setup do
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

    @tag authentication: [
           user_name: "non_admin",
           permissions: [:view_published_business_concepts, :view_quality_rule]
         ]
    test "rendes only authorized links", %{conn: conn, domain: domain} do
      %{id: id} = insert(:implementation, domain_id: domain.id)

      concept_id_authorized = System.unique_integer([:positive])

      ConceptCache.put(%{
        id: concept_id_authorized,
        domain_id: domain.id,
        name: "authorized_bc",
        updated_at: DateTime.utc_now()
      })

      CacheHelpers.insert_link(id, "implementation", "business_concept", concept_id_authorized)

      concept_id_forbidden = System.unique_integer([:positive])

      ConceptCache.put(%{
        id: concept_id_forbidden,
        name: "forbidden_bc",
        domain_id: System.unique_integer([:positive]),
        updated_at: DateTime.utc_now()
      })

      CacheHelpers.insert_link(id, "implementation", "business_concept", concept_id_forbidden)

      assert %{"data" => %{"links" => links}} =
               conn
               |> get(Routes.implementation_path(conn, :show, id))
               |> json_response(:ok)

      string_authorized_id = "#{concept_id_authorized}"
      assert [%{"resource_id" => ^string_authorized_id}] = links
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
          population: [],
          validations: [
            %{
              operator: %{
                name: "gt",
                value_type: "timestamp"
              },
              structure: %{id: 12_554},
              value: [%{raw: "2019-12-02 05:35:00"}]
            }
          ],
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

      assert equals_condition_row(
               Map.get(data, "validations"),
               Map.get(creation_attrs, "validations")
             )
    end

    @tag authentication: [role: "admin"]
    test "can create raw rule implementation with alias", %{conn: conn, swagger_schema: schema} do
      rule = insert(:rule)

      creation_attrs =
        %{
          implementation_key: "a1",
          implementation_type: "raw",
          rule_id: rule.id,
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

    @tag authentication: [user_name: "non_admin"]
    test "non admin without permission cannot create implementation", %{conn: conn} do
      rule = insert(:rule)

      creation_attrs =
        %{
          implementation_key: "a1",
          implementation_type: "raw",
          rule_id: rule.id,
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
        |> Map.Helpers.stringify_keys()

      assert conn
             |> post(Routes.implementation_path(conn, :create),
               rule_implementation: creation_attrs
             )
             |> json_response(:forbidden)
    end

    @tag authentication: [
           user_name: "non_admin",
           permissions: [:manage_raw_quality_rule_implementations]
         ]
    test "non admin with permission can create implementation", %{
      conn: conn,
      domain: %{id: domain_id}
    } do
      rule = insert(:rule, domain_id: domain_id)

      creation_attrs =
        %{
          implementation_key: "a1",
          implementation_type: "raw",
          rule_id: rule.id,
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
        %{
          implementation_key: "a1",
          implementation_type: "raw",
          rule_id: rule.id,
          raw_content: %{
            dataset: "cliente c join address a on c.address_id=a.id",
            population: nil,
            source_id: 88,
            validations: "c.city = 'MADRID'"
          },
          result_type: "percentage",
          minimum: 50,
          goal: 100,
          df_name: template_name,
          df_content: %{identifier_field: ""}
        }
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
      implementation = insert(:implementation)

      params =
        %{
          population: [
            %{
              value: [%{id: 11}],
              operator: %{
                name: "eq",
                value_type: "number"
              },
              structure: %{id: 60_311}
            }
          ]
        }
        |> Map.Helpers.stringify_keys()

      assert %{"data" => data} =
               conn
               |> put(Routes.implementation_path(conn, :update, implementation),
                 rule_implementation: params
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

      assert length(implementation.validations) == length(data["validations"])

      assert equals_condition_row(
               Map.get(data, "population"),
               Map.get(params, "population")
             )
    end

    @tag authentication: [user_name: "non_admin"]
    test "user without permissions cannot update", %{conn: conn} do
      implementation = insert(:implementation)

      params =
        %{
          population: [
            %{
              value: [%{id: 11}],
              operator: %{
                name: "eq",
                value_type: "number"
              },
              structure: %{id: 60_311}
            }
          ]
        }
        |> Map.Helpers.stringify_keys()

      assert conn
             |> put(Routes.implementation_path(conn, :update, implementation),
               rule_implementation: params
             )
             |> json_response(:forbidden)
    end

    @tag authentication: [
           user_name: "non_admin",
           permissions: [:manage_quality_rule_implementations]
         ]
    test "user with permissions can update", %{conn: conn, domain: %{id: domain_id}} do
      %{id: rule_id} = insert(:rule, domain_id: domain_id)
      implementation = insert(:implementation, rule_id: rule_id, domain_id: domain_id)

      params =
        %{
          population: [
            %{
              value: [%{id: 11}],
              operator: %{
                name: "eq",
                value_type: "number"
              },
              structure: %{id: 60_311}
            }
          ]
        }
        |> Map.Helpers.stringify_keys()

      assert conn
             |> put(Routes.implementation_path(conn, :update, implementation),
               rule_implementation: params
             )
             |> json_response(:ok)
    end

    @tag authentication: [role: "admin"]
    test "soft delete rule implementation", %{conn: conn, swagger_schema: schema} do
      implementation = insert(:implementation)
      insert(:rule_result, implementation: implementation)
      update_attrs = %{soft_delete: true}

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
      assert data["deleted_at"]
    end

    @tag authentication: [role: "admin"]
    test "cannot update rule implementation implementation key", %{
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
      update_attrs = %{soft_delete: true}

      CacheHelpers.put_implementation(implementation)
      %{id: concept_id} = CacheHelpers.insert_concept()
      CacheHelpers.insert_link(id, "implementation", "business_concept", concept_id)

      assert {:ok, %{id: ^id, deleted_at: nil}} = CacheHelpers.get_implementation(id)

      assert conn
             |> put(Routes.implementation_path(conn, :update, implementation),
               rule_implementation: update_attrs
             )
             |> json_response(:ok)

      assert {:ok, %{id: ^id, deleted_at: deleted_at}} = CacheHelpers.get_implementation(id)
      assert deleted_at != ""
    end

    @tag authentication: [role: "admin"]
    test "updating implementation will not update the cache if implementation is not linked", %{
      conn: conn
    } do
      %{id: id} = implementation = insert(:implementation)
      update_attrs = %{soft_delete: true}

      CacheHelpers.put_implementation(implementation)
      assert {:ok, %{id: ^id, deleted_at: nil}} = CacheHelpers.get_implementation(id)

      assert conn
             |> put(Routes.implementation_path(conn, :update, implementation),
               rule_implementation: update_attrs
             )
             |> json_response(:ok)

      assert {:ok, %{id: ^id, deleted_at: nil}} = CacheHelpers.get_implementation(id)
    end
  end

  describe "delete implementation" do
    @tag authentication: [role: "admin"]
    test "deletes chosen implementation", %{conn: conn} do
      implementation = insert(:implementation)

      assert conn
             |> delete(Routes.implementation_path(conn, :delete, implementation))
             |> response(:no_content)

      assert_error_sent(:not_found, fn ->
        get(conn, Routes.implementation_path(conn, :show, implementation))
      end)
    end

    @tag authentication: [user_name: "non_admin"]
    test "user without permissions cannot delete implementation", %{conn: conn} do
      implementation = insert(:implementation)

      assert conn
             |> delete(Routes.implementation_path(conn, :delete, implementation))
             |> response(:forbidden)
    end

    @tag authentication: [
           user_name: "non_admin",
           permissions: [:manage_quality_rule_implementations]
         ]
    test "user with permissions can delete implementation", %{
      conn: conn,
      domain: %{id: domain_id}
    } do
      implementation =
        insert(:implementation, rule: insert(:rule, domain_id: domain_id), domain_id: domain_id)

      assert conn
             |> delete(Routes.implementation_path(conn, :delete, implementation))
             |> response(:no_content)

      assert_error_sent(:not_found, fn ->
        get(conn, Routes.implementation_path(conn, :show, implementation))
      end)
    end
  end

  describe "search_rule_implementations" do
    @tag authentication: [role: "admin"]
    test "lists all implementations from a rule", %{
      conn: conn,
      swagger_schema: schema,
      implementation: %{rule_id: rule_id}
    } do
      assert %{"data" => data} =
               conn
               |> post(
                 Routes.rule_implementation_path(conn, :search_rule_implementations, rule_id)
               )
               |> validate_resp_schema(schema, "ImplementationsResponse")
               |> json_response(:ok)

      assert [%{"rule_id" => ^rule_id}] = data
    end

    @tag authentication: [role: "service"]
    test "service account can search implementations", %{
      conn: conn,
      swagger_schema: schema,
      implementation: %{rule_id: rule_id}
    } do
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
    test "search implementations with raw_content", %{
      conn: conn,
      swagger_schema: schema
    } do
      %{rule_id: rule_id} = insert(:raw_implementation)

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
      %{id: id, rule_id: rule_id} = insert(:implementation, deleted_at: DateTime.utc_now())

      assert %{"data" => data} =
               conn
               |> post(
                 Routes.rule_implementation_path(conn, :search_rule_implementations, rule_id,
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
    test "downlaod all implementations as csv", %{
      conn: conn,
      implementation: previous_implementation,
      implementations: new_implementations
    } do
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

      ts_0 = DateTime.to_iso8601(inserted_at_0)
      ts_1 = DateTime.to_iso8601(inserted_at_1)
      ts_2 = DateTime.to_iso8601(inserted_at_2)
      ts_3 = DateTime.to_iso8601(inserted_at_3)

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
