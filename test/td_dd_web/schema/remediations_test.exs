defmodule TdDdWeb.Schema.RemediationsTest do
  use TdDdWeb.ConnCase

  alias TdDdWeb.Schema.Types.Custom.Cursor

  @remediation_query """
  query Remediation($id: ID!) {
    remediation(id: $id) {
      id
      df_name
      df_content
      inserted_at
      updated_at
    }
  }
  """

  @remediations_query """
  query PaginatedRemediations(
    $last: Int,
    $before: Cursor,
    $first: Int,
    $after: Cursor
    $filters: RemediationFilterInput
  ) {
    remediationsConnection(
      last: $last,
      before: $before,
      first: $first,
      after: $after
      filters: $filters
    ) {
      totalCount
      page {
        id
      }
      pageInfo {
        startCursor
        endCursor
        hasNextPage
        hasPreviousPage
      }
    }
  }
  """

  setup do
    remediation_template = %{
      name: "remediation_template",
      label: "remediation_template",
      scope: "remediation",
      content: [
        %{
          "name" => "grupo_principal",
          "fields" => [
            %{
              "name" => "some_text_field",
              "type" => "string",
              "label" => "Some text field",
              "values" => nil,
              "widget" => "string",
              "default" => "",
              "cardinality" => "?",
              "description" => "Remediation plan text field"
            }
          ]
        }
      ]
    }

    CacheHelpers.insert_template(remediation_template)
    %{template: remediation_template}
  end

  describe "paginates and returns pagination info, without filters" do
    setup :create_remediations

    @tag authentication: [role: "user"]
    test "returns forbidden when queried by user role without permissions", %{
      conn: conn,
      reme_ids: [reme_id | _]
    } do
      assert %{"data" => data, "errors" => errors} =
               conn
               |> post("/api/v2", %{
                 "query" => @remediation_query,
                 "variables" => %{"id" => reme_id}
               })
               |> json_response(:ok)

      assert data == %{"remediation" => nil}
      assert [%{"message" => "forbidden"}] = errors
    end

    @tag authentication: [role: "user", permissions: [:manage_remediations]]
    test "returns not found remediation", %{conn: conn} do
      inexistent_id = 0

      assert %{"data" => data, "errors" => errors} =
               conn
               |> post("/api/v2", %{
                 "query" => @remediation_query,
                 "variables" => %{"id" => inexistent_id}
               })
               |> json_response(:ok)

      assert data == %{"remediation" => nil}
      assert [%{"message" => "not_found"}] = errors
    end

    @tag authentication: [role: "user", permissions: [:manage_remediations]]
    test "returns remediation", %{
      conn: conn,
      reme_ids: [reme_id | _],
      reme_ids_strings: [reme_id_string | _],
      template: %{name: df_name}
    } do
      assert %{"data" => data} =
               conn
               |> post("/api/v2", %{
                 "query" => @remediation_query,
                 "variables" => %{"id" => reme_id}
               })
               |> json_response(:ok)

      assert %{"remediation" => remediation} = data

      assert %{
               "id" => ^reme_id_string,
               "df_name" => ^df_name,
               "df_content" => %{"some_text_field" => "template_field_remediation"},
               "inserted_at" => _inserted_at,
               "updated_at" => _updated_at
             } = remediation
    end

    @tag authentication: [role: "user", permissions: [:manage_remediations]]
    test "regular user cannot list", %{
      conn: conn
    } do
      variables = %{
        "last" => 3
      }

      assert %{"data" => data, "errors" => errors} =
               conn
               |> post("/api/v2", %{
                 "query" => @remediations_query,
                 "variables" => variables
               })
               |> json_response(:ok)

      assert data == %{"remediationsConnection" => nil}
      assert [%{"message" => "forbidden"}] = errors
    end

    # before and after by ascending ID
    # first by ascending ID + limit
    # last by descending ID + limit
    # page always shown by descending id
    @tag authentication: [role: "service"]
    test "last (initial page)", %{
      conn: conn,
      reme_ids: reme_ids,
      reme_ids_strings: reme_ids_strings
    } do
      [_reme1, _reme2, _reme3, _reme4, _reme5, reme6, _reme7, reme8] = reme_ids

      [
        _reme1_string,
        _reme2_string,
        _reme3_string,
        _reme4_string,
        _reme5_string,
        reme6_string,
        reme7_string,
        reme8_string
      ] = reme_ids_strings

      variables = %{
        "last" => 3
      }

      assert %{"data" => data} =
               conn
               |> post("/api/v2", %{
                 "query" => @remediations_query,
                 "variables" => variables
               })
               |> json_response(:ok)

      assert %{
               "remediationsConnection" => %{
                 "page" => page,
                 "pageInfo" => page_info,
                 "totalCount" => 8
               }
             } = data

      assert [
               %{"id" => ^reme8_string},
               %{"id" => ^reme7_string},
               %{"id" => ^reme6_string}
             ] = page

      end_cursor = Cursor.encode(reme8)
      start_cursor = Cursor.encode(reme6)

      assert %{
               "startCursor" => ^start_cursor,
               "endCursor" => ^end_cursor,
               "hasPreviousPage" => true,
               "hasNextPage" => false
             } = page_info
    end

    @tag authentication: [role: "service"]
    test "first (last page)", %{
      conn: conn,
      reme_ids: reme_ids,
      reme_ids_strings: reme_ids_strings
    } do
      [reme1, _reme2, reme3, _reme4, _reme5, _reme6, _reme7, _reme8] = reme_ids

      [
        reme1_string,
        reme2_string,
        reme3_string,
        _reme4_string,
        _reme5_string,
        _reme6_string,
        _reme7_string,
        _reme8_string
      ] = reme_ids_strings

      variables = %{
        "first" => 3
      }

      assert %{"data" => data} =
               conn
               |> post("/api/v2", %{
                 "query" => @remediations_query,
                 "variables" => variables
               })
               |> json_response(:ok)

      assert %{
               "remediationsConnection" => %{
                 "page" => page,
                 "pageInfo" => page_info,
                 "totalCount" => 8
               }
             } = data

      assert [
               %{"id" => ^reme3_string},
               %{"id" => ^reme2_string},
               %{"id" => ^reme1_string}
             ] = page

      end_cursor = Cursor.encode(reme3)
      start_cursor = Cursor.encode(reme1)

      assert %{
               "startCursor" => ^start_cursor,
               "endCursor" => ^end_cursor,
               "hasPreviousPage" => false,
               "hasNextPage" => true
             } = page_info
    end

    @tag authentication: [role: "service"]
    test "before and last", %{
      conn: conn,
      reme_ids: reme_ids,
      reme_ids_strings: reme_ids_strings
    } do
      [_reme1, _reme2, reme3, _reme4, reme5, reme6, _reme7, _reme8] = reme_ids

      [
        _reme1_string,
        _reme2_string,
        reme3_string,
        reme4_string,
        reme5_string,
        _reme6_string,
        _reme7_string,
        _reme8_string
      ] = reme_ids_strings

      variables = %{
        "before" => Cursor.encode(reme6),
        "last" => 3
      }

      assert %{"data" => data} =
               conn
               |> post("/api/v2", %{
                 "query" => @remediations_query,
                 "variables" => variables
               })
               |> json_response(:ok)

      assert %{
               "remediationsConnection" => %{
                 "page" => page,
                 "pageInfo" => page_info,
                 "totalCount" => 8
               }
             } = data

      assert [
               %{"id" => ^reme5_string},
               %{"id" => ^reme4_string},
               %{"id" => ^reme3_string}
             ] = page

      end_cursor = Cursor.encode(reme5)
      start_cursor = Cursor.encode(reme3)

      assert %{
               "startCursor" => ^start_cursor,
               "endCursor" => ^end_cursor,
               "hasPreviousPage" => true,
               "hasNextPage" => true
             } = page_info
    end

    @tag authentication: [role: "service"]
    test "after, first", %{
      conn: conn,
      reme_ids: reme_ids,
      reme_ids_strings: reme_ids_strings
    } do
      [_reme1, _reme2, reme3, reme4, _reme5, reme6, _reme7, _reme8] = reme_ids

      [
        _reme1_string,
        _reme2_string,
        _reme3_string,
        reme4_string,
        reme5_string,
        reme6_string,
        _reme7_string,
        _reme8_string
      ] = reme_ids_strings

      variables = %{
        "after" => Cursor.encode(reme3),
        "first" => 3
      }

      assert %{"data" => data} =
               conn
               |> post("/api/v2", %{
                 "query" => @remediations_query,
                 "variables" => variables
               })
               |> json_response(:ok)

      assert %{
               "remediationsConnection" => %{
                 "page" => page,
                 "pageInfo" => page_info,
                 "totalCount" => 8
               }
             } = data

      assert [
               %{"id" => ^reme6_string},
               %{"id" => ^reme5_string},
               %{"id" => ^reme4_string}
             ] = page

      end_cursor = Cursor.encode(reme6)
      start_cursor = Cursor.encode(reme4)

      assert %{
               "startCursor" => ^start_cursor,
               "endCursor" => ^end_cursor,
               "hasPreviousPage" => true,
               "hasNextPage" => true
             } = page_info
    end

    defp create_remediations(%{template: %{name: df_name} = remediation_template} = context) do
      insert_implementation_fn =
        case context do
          %{domain: %{id: domain_id}} ->
            fn -> insert(:implementation, domain_id: domain_id) end

          _ ->
            fn -> insert(:implementation) end
        end

      reme_ids =
        Enum.map(
          1..8,
          fn _ ->
            %{id: implementation_id} = insert_implementation_fn.()
            %{id: rule_result_id} = insert(:rule_result, implementation_id: implementation_id)

            %{id: remediation_id} =
              insert(
                :remediation,
                df_name: df_name,
                df_content: %{"some_text_field" => "template_field_remediation"},
                rule_result_id: rule_result_id
              )

            remediation_id
          end
        )

      reme_ids_strings = Enum.map(reme_ids, &"#{&1}")
      %{template: remediation_template, reme_ids: reme_ids, reme_ids_strings: reme_ids_strings}
    end
  end

  describe "paginates and returns pagination info, with filters" do
    @tag authentication: [role: "service"]
    test "after, first and filters", %{
      conn: conn,
      template: %{name: df_name}
    } do
      reme_ids =
        [_reme1, _reme2, reme3, _reme4, reme5, _reme6, reme7, _reme8] =
        Enum.map(
          1..8,
          fn index ->
            %{id: rule_result_id} = insert(:rule_result)
            {:ok, inserted_at, 0} = DateTime.from_iso8601("2023-0#{index}-01T00:00:00Z")
            {:ok, updated_at, 0} = DateTime.from_iso8601("2023-0#{index}-02T00:00:00Z")

            %{id: remediation_id} =
              insert(
                :remediation,
                df_name: df_name,
                df_content: %{"some_text_field" => "template_field_remediation"},
                rule_result_id: rule_result_id,
                inserted_at: inserted_at,
                updated_at: updated_at
              )

            remediation_id
          end
        )

      [
        _reme1_string,
        _reme2_string,
        _reme3_string,
        _reme4_string,
        reme5_string,
        reme6_string,
        reme7_string,
        _reme8_string
      ] = Enum.map(reme_ids, &"#{&1}")

      variables = %{
        "after" => Cursor.encode(reme3),
        "first" => 3,
        "filters" => %{
          "inserted_since" => "2023-01-01T00:00:00Z",
          "updated_since" => "2023-05-01T00:00:00Z"
        }
      }

      assert %{"data" => data} =
               conn
               |> post("/api/v2", %{
                 "query" => @remediations_query,
                 "variables" => variables
               })
               |> json_response(:ok)

      assert %{
               "remediationsConnection" => %{
                 "page" => page,
                 "pageInfo" => page_info,
                 "totalCount" => 4
               }
             } = data

      assert [
               %{"id" => ^reme7_string},
               %{"id" => ^reme6_string},
               %{"id" => ^reme5_string}
             ] = page

      end_cursor = Cursor.encode(reme7)
      start_cursor = Cursor.encode(reme5)

      assert %{
               "startCursor" => ^start_cursor,
               "endCursor" => ^end_cursor,
               "hasPreviousPage" => false,
               "hasNextPage" => true
             } = page_info
    end
  end
end
