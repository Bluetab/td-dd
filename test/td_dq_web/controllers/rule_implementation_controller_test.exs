defmodule TdDqWeb.RuleImplementationControllerTest do
  use TdDqWeb.ConnCase
  use PhoenixSwagger.SchemaTest, "priv/static/swagger.json"
  import TdDq.Factory
  import TdDqWeb.Authentication, only: :functions
  alias TdDq.Cache.RuleLoader
  alias TdDq.Search.IndexWorker

  @invalid_rule_id -1

  @valid_dataset [
    %{structure: %{id: 14_080}},
    %{clauses: [%{left: %{id: 14_863}, right: %{id: 4028}}], structure: %{id: 3233}}
  ]

  setup_all do
    start_supervised(IndexWorker)
    start_supervised(RuleLoader)
    :ok
  end

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    @tag :admin_authenticated
    test "lists all rule_implementations", %{conn: conn, swagger_schema: schema} do
      conn = get(conn, Routes.rule_implementation_path(conn, :index))
      validate_resp_schema(conn, schema, "RuleImplementationsResponse")
      assert json_response(conn, :ok)["data"] == []
    end

    @tag :admin_authenticated
    test "lists all rule_implementations filtered by rule business_concept_id and state", %{
      conn: conn,
      swagger_schema: schema
    } do
      rule1 = insert(:rule, business_concept_id: "xyz", active: true)
      rule2 = insert(:rule)
      insert(:rule_implementation, implementation_key: "ri1", rule: rule1)
      insert(:rule_implementation, implementation_key: "ri2", rule: rule1)
      insert(:rule_implementation, implementation_key: "ri3", rule: rule1)
      insert(:rule_implementation, implementation_key: "ri4", rule: rule2)
      insert(:rule_implementation_raw, implementation_key: "ri5", rule: rule1)

      conn =
        get(conn, Routes.rule_implementation_path(conn, :index), %{
          is_rule_active: true,
          rule_business_concept_id: "xyz"
        })

      validate_resp_schema(conn, schema, "RuleImplementationsResponse")
      assert length(json_response(conn, :ok)["data"]) == 4
    end
  end

  describe "create rule_implementation" do
    @tag :admin_authenticated
    test "renders rule_implementation when data is valid", %{conn: conn, swagger_schema: schema} do
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

      conn =
        post(conn, Routes.rule_implementation_path(conn, :create),
          rule_implementation: creation_attrs
        )

      validate_resp_schema(conn, schema, "RuleImplementationResponse")
      assert %{"id" => id} = json_response(conn, :created)["data"]

      conn = recycle_and_put_headers(conn)

      conn = get(conn, Routes.rule_implementation_path(conn, :show, id))
      validate_resp_schema(conn, schema, "RuleImplementationResponse")
      json_response = json_response(conn, :ok)["data"]

      assert rule.id == json_response["rule_id"]

      assert equals_condition_row(
               Map.get(json_response, "validations"),
               Map.get(creation_attrs, "validations")
             )
    end

    @tag :admin_authenticated
    test "renders errors when data is invalid", %{conn: conn} do
      rule = insert(:rule)

      creation_attrs =
        Map.from_struct(
          build(:rule_implementation,
            rule_id: rule.id,
            dataset: [
              %{id: 14_080},
              %{id: 3233, right: %{id: "a"}, left: %{id: 22}, join_type: "inner"}
            ]
          )
        )

      conn =
        post(conn, Routes.rule_implementation_path(conn, :create),
          rule_implementation: creation_attrs
        )

      assert json_response(conn, :unprocessable_entity)["errors"] != %{}
    end

    @tag :admin_authenticated
    test "renders errors when validations is invalid", %{conn: conn} do
      rule = insert(:rule)

      creation_attrs =
        Map.from_struct(
          build(:rule_implementation,
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
        )

      conn =
        post(conn, Routes.rule_implementation_path(conn, :create),
          rule_implementation: creation_attrs
        )

      assert json_response(conn, :unprocessable_entity)["errors"] != []
    end
  end

  describe "update rule_implementation" do
    @tag :admin_authenticated
    test "renders rule_implementation when data is valid", %{conn: conn, swagger_schema: schema} do
      rule_implementation = insert(:rule_implementation)

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

      conn =
        put(conn, Routes.rule_implementation_path(conn, :update, rule_implementation),
          rule_implementation: update_attrs
        )

      validate_resp_schema(conn, schema, "RuleImplementationResponse")
      assert %{"id" => id} = json_response(conn, :ok)["data"]

      conn = recycle_and_put_headers(conn)

      conn = get(conn, Routes.rule_implementation_path(conn, :show, id))
      validate_resp_schema(conn, schema, "RuleImplementationResponse")
      json_response = json_response(conn, :ok)["data"]

      assert rule_implementation.rule_id == json_response["rule_id"]

      assert length(rule_implementation.validations) == length(json_response["validations"])

      assert equals_condition_row(
               Map.get(json_response, "population"),
               Map.get(update_attrs, "population")
             )
    end

    @tag :admin_authenticated
    test "rule implementation cannot be updated if it has rule results", %{
      conn: conn,
      swagger_schema: schema
    } do
      rule_implementation = insert(:rule_implementation)

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
        implementation_key: rule_implementation.implementation_key,
        result: 10 |> Decimal.round(2),
        date: DateTime.utc_now()
      )

      conn =
        put(conn, Routes.rule_implementation_path(conn, :update, rule_implementation),
          rule_implementation: update_attrs
        )

      validate_resp_schema(conn, schema, "RuleImplementationResponse")
      assert json_response(conn, :unprocessable_entity)["errors"] != %{}
    end

    @tag :admin_authenticated
    test "soft delete rule implementation", %{conn: conn, swagger_schema: schema} do
      rule_implementation = insert(:rule_implementation)

      update_attrs = %{soft_delete: true}

      conn =
        put(conn, Routes.rule_implementation_path(conn, :update, rule_implementation),
          rule_implementation: update_attrs
        )

      validate_resp_schema(conn, schema, "RuleImplementationResponse")
      assert %{"id" => id} = json_response(conn, :ok)["data"]

      conn = recycle_and_put_headers(conn)

      conn = get(conn, Routes.rule_implementation_path(conn, :show, id))
      validate_resp_schema(conn, schema, "RuleImplementationResponse")
      json_response = json_response(conn, :ok)["data"]

      assert rule_implementation.rule_id == json_response["rule_id"]
      assert not is_nil(json_response["deleted_at"])
    end

    @tag :admin_authenticated
    test "cannot update rule implementation implementation key", %{
      conn: conn,
      swagger_schema: schema
    } do
      rule_implementation = insert(:rule_implementation)
      update_attrs = %{implementation_key: "updated"}

      conn =
        put(conn, Routes.rule_implementation_path(conn, :update, rule_implementation),
          rule_implementation: update_attrs
        )

      validate_resp_schema(conn, schema, "RuleImplementationResponse")
      assert %{"id" => id} = json_response(conn, :ok)["data"]

      conn = recycle_and_put_headers(conn)

      conn = get(conn, Routes.rule_implementation_path(conn, :show, id))
      validate_resp_schema(conn, schema, "RuleImplementationResponse")
      json_response = json_response(conn, :ok)["data"]

      assert rule_implementation.rule_id == json_response["rule_id"]
      assert json_response["implementation_key"] != update_attrs.implementation_key
    end

    @tag :admin_authenticated
    test "renders errors when data is invalid", %{conn: conn} do
      rule_implementation = insert(:rule_implementation)

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

      conn =
        put(conn, Routes.rule_implementation_path(conn, :update, rule_implementation),
          rule_implementation: update_attrs
        )

      assert json_response(conn, :unprocessable_entity)["errors"] != %{}
    end
  end

  describe "delete rule_implementation" do
    @tag :admin_authenticated
    test "deletes chosen rule_implementation", %{conn: conn} do
      rule_implementation = insert(:rule_implementation)
      conn = delete(conn, Routes.rule_implementation_path(conn, :delete, rule_implementation))
      assert response(conn, 204)

      conn = recycle_and_put_headers(conn)

      assert_error_sent(404, fn ->
        get(conn, Routes.rule_implementation_path(conn, :show, rule_implementation))
      end)
    end
  end

  describe "search_rule_implementations" do
    @tag :admin_authenticated
    test "lists all rule_implementations from a rule", %{conn: conn, swagger_schema: schema} do
      rule = insert(:rule)

      creation_attrs =
        Map.from_struct(
          build(
            :rule_implementation,
            rule_id: rule.id
          )
        )

      conn =
        post(conn, Routes.rule_implementation_path(conn, :create),
          rule_implementation: creation_attrs
        )

      validate_resp_schema(conn, schema, "RuleImplementationResponse")
      assert response(conn, :created)

      conn = recycle_and_put_headers(conn)

      conn =
        post(
          conn,
          Routes.rule_rule_implementation_path(conn, :search_rule_implementations, rule.id)
        )

      validate_resp_schema(conn, schema, "RuleImplementationsResponse")
      json_response = List.first(json_response(conn, :ok)["data"])

      assert creation_attrs[:rule_id] == json_response["rule_id"]
      assert creation_attrs[:system_params] == json_response["system_params"]
      assert creation_attrs[:system] == json_response["system"]

      conn = recycle_and_put_headers(conn)

      conn =
        post(
          conn,
          Routes.rule_rule_implementation_path(
            conn,
            :search_rule_implementations,
            @invalid_rule_id
          )
        )

      validate_resp_schema(conn, schema, "RuleImplementationsResponse")
      assert json_response(conn, :ok)["data"] == []
    end

    @tag :admin_authenticated
    test "lists all deleted rule_implementations of a rule", %{conn: conn, swagger_schema: schema} do
      rule = insert(:rule)

      rule_implementation =
        insert(:rule_implementation, rule: rule, deleted_at: DateTime.utc_now())

      conn =
        post(
          conn,
          Routes.rule_rule_implementation_path(conn, :search_rule_implementations, rule.id, %{
            "status" => "deleted"
          })
        )

      validate_resp_schema(conn, schema, "RuleImplementationsResponse")
      json_response = List.first(json_response(conn, :ok)["data"])

      assert Map.get(rule_implementation, :rule_id) == json_response["rule_id"]
      assert Map.get(rule_implementation, :system_params) == json_response["system_params"]
      assert Map.get(rule_implementation, :system) == json_response["system"]
    end
  end

  describe "search_rules_implementations" do
    @tag :admin_authenticated
    test "lists all rule_implementations given some request params", %{
      conn: conn,
      swagger_schema: schema
    } do
      conn = post(conn, Routes.rule_implementation_path(conn, :search_rules_implementations, %{}))

      validate_resp_schema(conn, schema, "RuleImplementationsResponse")
      assert json_response(conn, :ok)["data"] == []
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
