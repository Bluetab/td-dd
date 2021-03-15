defmodule TdDqWeb.ImplementationControllerTest do
  use TdDqWeb.ConnCase
  use PhoenixSwagger.SchemaTest, "priv/static/swagger.json"

  alias TdCache.StructureCache
  alias TdCache.SystemCache
  alias TdDq.Cache.ImplementationLoader
  alias TdDq.Cache.RuleLoader
  alias TdDq.Search.IndexWorker

  @valid_dataset [
    %{structure: %{id: 14_080}},
    %{clauses: [%{left: %{id: 14_863}, right: %{id: 4028}}], structure: %{id: 3233}}
  ]

  setup_all do
    start_supervised(IndexWorker)
    start_supervised(RuleLoader)
    start_supervised(ImplementationLoader)

    system = %{id: 1, external_id: "sys1_ext_id", name: "sys1"}

    structure = %{
      id: 14_080,
      name: "name",
      external_id: "ext_id",
      group: "group",
      type: "type",
      path: ["foo", "bar"],
      updated_at: DateTime.utc_now(),
      metadata: %{"alias" => "source_alias"},
      system_id: system.id
    }

    {:ok, _} = SystemCache.put(system)
    {:ok, _} = StructureCache.put(structure)

    on_exit(fn ->
      SystemCache.delete(system.id)
      StructureCache.delete(structure.id)
    end)

    [structure: structure]
  end

  setup do
    [implementation: insert(:implementation)]
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
          ]
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
            structure_alias: "str_alias",
            source_id: 88,
            validations: "c.city = 'MADRID'"
          }
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
                "source_id" => ["can't be blank"],
                "structure_alias" => ["can't be blank"]
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

    @tag authentication: [role: "admin"]
    test "implementation cannot be updated if it has rule results", %{conn: conn} do
      implementation = insert(:implementation)

      update_attrs =
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

      insert(
        :rule_result,
        implementation_key: implementation.implementation_key,
        result: 10 |> Decimal.round(2),
        date: DateTime.utc_now()
      )

      assert %{"errors" => _errors} =
               conn
               |> put(Routes.implementation_path(conn, :update, implementation),
                 rule_implementation: update_attrs
               )
               |> json_response(:unprocessable_entity)
    end

    @tag authentication: [role: "admin"]
    test "soft delete rule implementation", %{conn: conn, swagger_schema: schema} do
      implementation = insert(:implementation)
      insert(:rule_result, implementation_key: implementation.implementation_key)
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
      assert data["implementation_key"] != update_attrs.implementation_key
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
      %{id: id} = insert(:raw_implementation)

      params = %{
        "rule_implementation" => %{
          "raw_content" => %{
            "structure_alias" => "alias",
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
      swagger_schema: schema,
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
