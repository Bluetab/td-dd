defmodule TdDdWeb.Schema.GrantsTest do
  use TdDdWeb.ConnCase

  @grant_query """
  query Grants($filters: GrantsFilter) {
    grants(filters: $filters) {
      totalCount
      pageInfo {
          startCursor
          endCursor
          hasNextPage
          hasPreviousPage
      }
      page {
          id
          detail
          startDate
          endDate
          userId
          dataStructureId
          dataStructure {
            id
          }
          insertedAt
          updatedAt
          sourceUserName
          pendingRemoval
          externalRef
          __typename
      }
    }
  }
  """

  @paginate_grant_query """
  query Grants($first: Int, $last: Int, $before: Cursor, $after: Cursor) {
    grants(first: $first, last: $last, before: $before, after: $after) {
      totalCount
      pageInfo {
          startCursor
          endCursor
          hasNextPage
          hasPreviousPage
      }
      page {
          id
      }
    }
  }
  """

  describe "Grants query" do
    @tag authentication: [role: "user"]
    test "returns forbidden if user has no permissions", %{conn: conn} do
      %{id: user_id} = CacheHelpers.insert_user()
      %{id: ds_id} = insert(:data_structure)

      start_date = Date.utc_today() |> Date.add(-1)
      end_date = Date.utc_today() |> Date.add(2)

      insert(
        :grant,
        data_structure_id: ds_id,
        user_id: user_id,
        start_date: start_date,
        end_date: end_date
      )

      assert %{"data" => data, "errors" => errors} =
               conn
               |> post("/api/v2", %{"query" => @grant_query})
               |> json_response(:ok)

      assert data == %{"grants" => nil}
      assert [%{"message" => "forbidden"}] = errors
    end

    @tag authentication: [role: "admin"]
    test "list grants with admin user", %{conn: conn} do
      %{id: user_id_1} = CacheHelpers.insert_user()
      %{id: user_id_2} = CacheHelpers.insert_user()
      %{id: ds_id} = insert(:data_structure)

      start_date = Date.utc_today() |> Date.add(-1)
      end_date = Date.utc_today() |> Date.add(2)

      insert(
        :grant,
        data_structure_id: ds_id,
        user_id: user_id_1,
        start_date: start_date,
        end_date: end_date
      )

      insert(
        :grant,
        data_structure_id: ds_id,
        user_id: user_id_2,
        start_date: start_date,
        end_date: end_date
      )

      assert %{"data" => data} =
               conn
               |> post("/api/v2", %{"query" => @grant_query})
               |> json_response(:ok)

      assert %{"grants" => %{"page" => grants, "totalCount" => 2}} = data
      assert length(grants) == 2
    end

    @tag authentication: [
           role: "user",
           permissions: [:approve_grant_request]
         ]
    test "list grants with user with permission", %{conn: conn, domain: %{id: domain_id}} do
      %{id: user_id_1} = CacheHelpers.insert_user()
      %{id: user_id_2} = CacheHelpers.insert_user()
      %{id: ds_id} = insert(:data_structure, domain_ids: [domain_id])

      start_date = Date.utc_today() |> Date.add(-1)
      end_date = Date.utc_today() |> Date.add(2)

      insert(
        :grant,
        data_structure_id: ds_id,
        user_id: user_id_1,
        start_date: start_date,
        end_date: end_date
      )

      insert(
        :grant,
        data_structure_id: ds_id,
        user_id: user_id_2,
        start_date: start_date,
        end_date: end_date
      )

      assert %{"data" => data} =
               conn
               |> post("/api/v2", %{"query" => @grant_query})
               |> json_response(:ok)

      assert %{"grants" => %{"page" => grants, "totalCount" => 2}} = data
      assert length(grants) == 2
    end

    @tag authentication: [
           role: "user",
           permissions: [:approve_grant_request, :view_data_structure]
         ]
    test "list grants filtered by grants_ids", %{conn: conn, domain: %{id: domain_id}} do
      %{id: user_id_1} = CacheHelpers.insert_user()
      %{id: user_id_2} = CacheHelpers.insert_user()
      ds1 = insert(:data_structure, domain_ids: [domain_id])
      ds2 = insert(:data_structure, domain_ids: [domain_id])
      ds3 = insert(:data_structure, domain_ids: [domain_id])

      start_date = Date.utc_today() |> Date.add(-1)
      end_date = Date.utc_today() |> Date.add(2)

      %{id: grant_id_1} =
        insert(
          :grant,
          data_structure: ds1,
          user_id: user_id_1,
          start_date: start_date,
          end_date: end_date
        )

      %{id: grant_id_2} =
        insert(
          :grant,
          data_structure: ds2,
          user_id: user_id_2,
          start_date: start_date,
          end_date: end_date
        )

      insert(
        :grant,
        data_structure: ds3,
        user_id: user_id_2,
        start_date: start_date,
        end_date: end_date
      )

      assert %{"data" => data} =
               conn
               |> post(
                 "/api/v2",
                 %{
                   "query" => @grant_query,
                   "variables" => %{
                     "filters" => %{
                       "ids" => [grant_id_1, grant_id_2]
                     }
                   }
                 }
               )
               |> json_response(:ok)

      assert %{
               "grants" => %{
                 "page" => [
                   %{
                     "id" => data_grant_id_2
                   },
                   %{
                     "id" => data_grant_id_1
                   }
                 ],
                 "totalCount" => 2
               }
             } = data

      assert data_grant_id_1 == "#{grant_id_1}"
      assert data_grant_id_2 == "#{grant_id_2}"
    end

    @tag authentication: [
           role: "user",
           permissions: [:approve_grant_request, :view_data_structure]
         ]
    test "list grants filtered by data_structure_id", %{conn: conn, domain: %{id: domain_id}} do
      %{id: user_id_1} = CacheHelpers.insert_user()
      %{id: user_id_2} = CacheHelpers.insert_user()
      %{id: ds_id_1} = ds1 = insert(:data_structure, domain_ids: [domain_id])
      %{id: ds_id_2} = ds2 = insert(:data_structure, domain_ids: [domain_id])
      ds3 = insert(:data_structure, domain_ids: [domain_id])

      start_date = Date.utc_today() |> Date.add(-1)
      end_date = Date.utc_today() |> Date.add(2)

      insert(
        :grant,
        data_structure: ds1,
        user_id: user_id_1,
        start_date: start_date,
        end_date: end_date
      )

      insert(
        :grant,
        data_structure: ds2,
        user_id: user_id_2,
        start_date: start_date,
        end_date: end_date
      )

      insert(
        :grant,
        data_structure: ds3,
        user_id: user_id_2,
        start_date: start_date,
        end_date: end_date
      )

      assert %{"data" => data} =
               conn
               |> post(
                 "/api/v2",
                 %{
                   "query" => @grant_query,
                   "variables" => %{
                     "filters" => %{
                       "data_structure_ids" => [ds_id_1, ds_id_2]
                     }
                   }
                 }
               )
               |> json_response(:ok)

      ds_id_1_str = "#{ds_id_1}"
      ds_id_2_str = "#{ds_id_2}"

      assert %{
               "grants" => %{
                 "page" => [
                   %{
                     "dataStructureId" => ^ds_id_2_str,
                     "dataStructure" => %{
                       "id" => ^ds_id_2_str
                     }
                   },
                   %{
                     "dataStructureId" => ^ds_id_1_str,
                     "dataStructure" => %{
                       "id" => ^ds_id_1_str
                     }
                   }
                 ],
                 "totalCount" => 2
               }
             } = data
    end

    @tag authentication: [
           role: "user",
           permissions: [:approve_grant_request, :view_data_structure]
         ]
    test "list grants filtered by users_ids", %{conn: conn, domain: %{id: domain_id}} do
      %{id: user_id_1} = CacheHelpers.insert_user()
      %{id: user_id_2} = CacheHelpers.insert_user()
      %{id: user_id_3} = CacheHelpers.insert_user()
      ds1 = insert(:data_structure, domain_ids: [domain_id])
      ds2 = insert(:data_structure, domain_ids: [domain_id])
      ds3 = insert(:data_structure, domain_ids: [domain_id])

      start_date = Date.utc_today() |> Date.add(-1)
      end_date = Date.utc_today() |> Date.add(2)

      insert(
        :grant,
        data_structure: ds1,
        user_id: user_id_1,
        start_date: start_date,
        end_date: end_date
      )

      insert(
        :grant,
        data_structure: ds2,
        user_id: user_id_2,
        start_date: start_date,
        end_date: end_date
      )

      insert(
        :grant,
        data_structure: ds3,
        user_id: user_id_3,
        start_date: start_date,
        end_date: end_date
      )

      assert %{"data" => data} =
               conn
               |> post(
                 "/api/v2",
                 %{
                   "query" => @grant_query,
                   "variables" => %{
                     "filters" => %{
                       "userIds" => [user_id_1, user_id_2]
                     }
                   }
                 }
               )
               |> json_response(:ok)

      user_id_1_str = "#{user_id_1}"
      user_id_2_str = "#{user_id_2}"

      assert %{
               "grants" => %{
                 "page" => [
                   %{
                     "userId" => ^user_id_2_str
                   },
                   %{
                     "userId" => ^user_id_1_str
                   }
                 ],
                 "totalCount" => 2
               }
             } = data
    end

    @tag authentication: [
           role: "user",
           permissions: [:approve_grant_request, :view_data_structure]
         ]
    test "list grants filtered by pending_removal", %{conn: conn, domain: %{id: domain_id}} do
      %{id: user_id_1} = CacheHelpers.insert_user()
      %{id: user_id_2} = CacheHelpers.insert_user()
      ds1 = insert(:data_structure, domain_ids: [domain_id])
      ds2 = insert(:data_structure, domain_ids: [domain_id])
      ds3 = insert(:data_structure, domain_ids: [domain_id])

      start_date = Date.utc_today() |> Date.add(-1)
      end_date = Date.utc_today() |> Date.add(2)

      %{id: grant_id_1} =
        insert(
          :grant,
          data_structure: ds1,
          user_id: user_id_1,
          start_date: start_date,
          end_date: end_date,
          pending_removal: true
        )

      %{id: grant_id_2} =
        insert(
          :grant,
          data_structure: ds2,
          user_id: user_id_2,
          start_date: start_date,
          end_date: end_date
        )

      %{id: grant_id_3} =
        insert(
          :grant,
          data_structure: ds3,
          user_id: user_id_2,
          start_date: start_date,
          end_date: end_date
        )

      assert %{"data" => data} =
               conn
               |> post(
                 "/api/v2",
                 %{
                   "query" => @grant_query,
                   "variables" => %{
                     "filters" => %{
                       "pendingRemoval" => true
                     }
                   }
                 }
               )
               |> json_response(:ok)

      grant_id_1_str = "#{grant_id_1}"
      grant_id_2_str = "#{grant_id_2}"
      grant_id_3_str = "#{grant_id_3}"

      assert %{
               "grants" => %{
                 "page" => [
                   %{
                     "id" => ^grant_id_1_str
                   }
                 ],
                 "totalCount" => 1
               }
             } = data

      assert %{"data" => data} =
               conn
               |> post(
                 "/api/v2",
                 %{
                   "query" => @grant_query,
                   "variables" => %{
                     "filters" => %{
                       "pendingRemoval" => false
                     }
                   }
                 }
               )
               |> json_response(:ok)

      assert %{
               "grants" => %{
                 "page" => [
                   %{
                     "id" => ^grant_id_3_str
                   },
                   %{
                     "id" => ^grant_id_2_str
                   }
                 ],
                 "totalCount" => 2
               }
             } = data
    end

    # Test Date filters

    @tag authentication: [
           role: "user",
           permissions: [:approve_grant_request, :view_data_structure]
         ]
    test "list grants filtered by start_date gt", %{conn: conn, domain: %{id: domain_id}} do
      %{id: user_id_1} = CacheHelpers.insert_user()
      ds1 = insert(:data_structure, domain_ids: [domain_id])
      ds2 = insert(:data_structure, domain_ids: [domain_id])
      ds3 = insert(:data_structure, domain_ids: [domain_id])

      start_date_1 = Date.utc_today() |> Date.add(-1)
      end_date_1 = Date.utc_today() |> Date.add(1)

      start_date_2 = Date.utc_today() |> Date.add(-2)
      end_date_2 = Date.utc_today() |> Date.add(2)

      start_date_3 = Date.utc_today() |> Date.add(-3)
      end_date_3 = Date.utc_today() |> Date.add(3)

      %{id: grant_id_1} =
        insert(
          :grant,
          data_structure: ds1,
          user_id: user_id_1,
          start_date: start_date_1,
          end_date: end_date_1
        )

      %{id: grant_id_2} =
        insert(
          :grant,
          data_structure: ds2,
          user_id: user_id_1,
          start_date: start_date_2,
          end_date: end_date_2
        )

      %{id: _grant_id_3} =
        insert(
          :grant,
          data_structure: ds3,
          user_id: user_id_1,
          start_date: start_date_3,
          end_date: end_date_3
        )

      assert %{"data" => data} =
               conn
               |> post(
                 "/api/v2",
                 %{
                   "query" => @grant_query,
                   "variables" => %{
                     "filters" => %{
                       "startDate" => %{
                         "gt" => Date.utc_today() |> Date.add(-3) |> to_string
                       }
                     }
                   }
                 }
               )
               |> json_response(:ok)

      grant_id_1_str = "#{grant_id_1}"
      grant_id_2_str = "#{grant_id_2}"

      assert %{
               "grants" => %{
                 "page" => [
                   %{
                     "id" => ^grant_id_2_str
                   },
                   %{
                     "id" => ^grant_id_1_str
                   }
                 ],
                 "totalCount" => 2
               }
             } = data
    end

    @tag authentication: [
           role: "user",
           permissions: [:approve_grant_request, :view_data_structure]
         ]
    test "list grants filtered by start_date lt", %{conn: conn, domain: %{id: domain_id}} do
      %{id: user_id_1} = CacheHelpers.insert_user()
      ds1 = insert(:data_structure, domain_ids: [domain_id])
      ds2 = insert(:data_structure, domain_ids: [domain_id])
      ds3 = insert(:data_structure, domain_ids: [domain_id])

      start_date_1 = Date.utc_today() |> Date.add(-1)
      end_date_1 = Date.utc_today() |> Date.add(1)

      start_date_2 = Date.utc_today() |> Date.add(-2)
      end_date_2 = Date.utc_today() |> Date.add(2)

      start_date_3 = Date.utc_today() |> Date.add(-3)
      end_date_3 = Date.utc_today() |> Date.add(3)

      %{id: _grant_id_1} =
        insert(
          :grant,
          data_structure: ds1,
          user_id: user_id_1,
          start_date: start_date_1,
          end_date: end_date_1
        )

      %{id: grant_id_2} =
        insert(
          :grant,
          data_structure: ds2,
          user_id: user_id_1,
          start_date: start_date_2,
          end_date: end_date_2
        )

      %{id: grant_id_3} =
        insert(
          :grant,
          data_structure: ds3,
          user_id: user_id_1,
          start_date: start_date_3,
          end_date: end_date_3
        )

      assert %{"data" => data} =
               conn
               |> post(
                 "/api/v2",
                 %{
                   "query" => @grant_query,
                   "variables" => %{
                     "filters" => %{
                       "startDate" => %{
                         "lt" => Date.utc_today() |> Date.add(-1) |> to_string
                       }
                     }
                   }
                 }
               )
               |> json_response(:ok)

      grant_id_2_str = "#{grant_id_2}"
      grant_id_3_str = "#{grant_id_3}"

      assert %{
               "grants" => %{
                 "page" => [
                   %{
                     "id" => ^grant_id_3_str
                   },
                   %{
                     "id" => ^grant_id_2_str
                   }
                 ],
                 "totalCount" => 2
               }
             } = data
    end

    @tag authentication: [
           role: "user",
           permissions: [:approve_grant_request, :view_data_structure]
         ]
    test "list grants filtered by start_date eq", %{conn: conn, domain: %{id: domain_id}} do
      %{id: user_id_1} = CacheHelpers.insert_user()
      ds1 = insert(:data_structure, domain_ids: [domain_id])
      ds2 = insert(:data_structure, domain_ids: [domain_id])
      ds3 = insert(:data_structure, domain_ids: [domain_id])

      start_date_1 = Date.utc_today() |> Date.add(-1)
      end_date_1 = Date.utc_today() |> Date.add(1)

      start_date_2 = Date.utc_today() |> Date.add(-2)
      end_date_2 = Date.utc_today() |> Date.add(2)

      start_date_3 = Date.utc_today() |> Date.add(-3)
      end_date_3 = Date.utc_today() |> Date.add(3)

      %{id: grant_id_1} =
        insert(
          :grant,
          data_structure: ds1,
          user_id: user_id_1,
          start_date: start_date_1,
          end_date: end_date_1
        )

      %{id: _grant_id_2} =
        insert(
          :grant,
          data_structure: ds2,
          user_id: user_id_1,
          start_date: start_date_2,
          end_date: end_date_2
        )

      %{id: _grant_id_3} =
        insert(
          :grant,
          data_structure: ds3,
          user_id: user_id_1,
          start_date: start_date_3,
          end_date: end_date_3
        )

      assert %{"data" => data} =
               conn
               |> post(
                 "/api/v2",
                 %{
                   "query" => @grant_query,
                   "variables" => %{
                     "filters" => %{
                       "startDate" => %{
                         "eq" => Date.utc_today() |> Date.add(-1) |> to_string
                       }
                     }
                   }
                 }
               )
               |> json_response(:ok)

      grant_id_1_str = "#{grant_id_1}"

      assert %{
               "grants" => %{
                 "page" => [
                   %{
                     "id" => ^grant_id_1_str
                   }
                 ],
                 "totalCount" => 1
               }
             } = data
    end

    @tag authentication: [
           role: "user",
           permissions: [:approve_grant_request, :view_data_structure]
         ]
    test "list grants filtered by start_date gt and lt", %{conn: conn, domain: %{id: domain_id}} do
      %{id: user_id_1} = CacheHelpers.insert_user()
      ds1 = insert(:data_structure, domain_ids: [domain_id])
      ds2 = insert(:data_structure, domain_ids: [domain_id])
      ds3 = insert(:data_structure, domain_ids: [domain_id])

      start_date_1 = Date.utc_today() |> Date.add(-1)
      end_date_1 = Date.utc_today() |> Date.add(1)

      start_date_2 = Date.utc_today() |> Date.add(-2)
      end_date_2 = Date.utc_today() |> Date.add(2)

      start_date_3 = Date.utc_today() |> Date.add(-3)
      end_date_3 = Date.utc_today() |> Date.add(3)

      %{id: _grant_id_1} =
        insert(
          :grant,
          data_structure: ds1,
          user_id: user_id_1,
          start_date: start_date_1,
          end_date: end_date_1
        )

      %{id: grant_id_2} =
        insert(
          :grant,
          data_structure: ds2,
          user_id: user_id_1,
          start_date: start_date_2,
          end_date: end_date_2
        )

      %{id: _grant_id_3} =
        insert(
          :grant,
          data_structure: ds3,
          user_id: user_id_1,
          start_date: start_date_3,
          end_date: end_date_3
        )

      assert %{"data" => data} =
               conn
               |> post(
                 "/api/v2",
                 %{
                   "query" => @grant_query,
                   "variables" => %{
                     "filters" => %{
                       "startDate" => %{
                         "gt" => Date.utc_today() |> Date.add(-3) |> to_string,
                         "lt" => Date.utc_today() |> Date.add(-1) |> to_string
                       }
                     }
                   }
                 }
               )
               |> json_response(:ok)

      grant_id_2_str = "#{grant_id_2}"

      assert %{
               "grants" => %{
                 "page" => [
                   %{
                     "id" => ^grant_id_2_str
                   }
                 ],
                 "totalCount" => 1
               }
             } = data
    end

    @tag authentication: [
           role: "user",
           permissions: [:approve_grant_request, :view_data_structure]
         ]
    test "list grants filtered by end_date gt", %{conn: conn, domain: %{id: domain_id}} do
      %{id: user_id_1} = CacheHelpers.insert_user()
      ds1 = insert(:data_structure, domain_ids: [domain_id])
      ds2 = insert(:data_structure, domain_ids: [domain_id])
      ds3 = insert(:data_structure, domain_ids: [domain_id])

      start_date_1 = Date.utc_today() |> Date.add(-1)
      end_date_1 = Date.utc_today() |> Date.add(1)

      start_date_2 = Date.utc_today() |> Date.add(-2)
      end_date_2 = Date.utc_today() |> Date.add(2)

      start_date_3 = Date.utc_today() |> Date.add(-3)
      end_date_3 = Date.utc_today() |> Date.add(3)

      %{id: _grant_id_1} =
        insert(
          :grant,
          data_structure: ds1,
          user_id: user_id_1,
          start_date: start_date_1,
          end_date: end_date_1
        )

      %{id: grant_id_2} =
        insert(
          :grant,
          data_structure: ds2,
          user_id: user_id_1,
          start_date: start_date_2,
          end_date: end_date_2
        )

      %{id: grant_id_3} =
        insert(
          :grant,
          data_structure: ds3,
          user_id: user_id_1,
          start_date: start_date_3,
          end_date: end_date_3
        )

      assert %{"data" => data} =
               conn
               |> post(
                 "/api/v2",
                 %{
                   "query" => @grant_query,
                   "variables" => %{
                     "filters" => %{
                       "endDate" => %{
                         "gt" => Date.utc_today() |> Date.add(1) |> to_string
                       }
                     }
                   }
                 }
               )
               |> json_response(:ok)

      grant_id_2_str = "#{grant_id_2}"
      grant_id_3_str = "#{grant_id_3}"

      assert %{
               "grants" => %{
                 "page" => [
                   %{
                     "id" => ^grant_id_3_str
                   },
                   %{
                     "id" => ^grant_id_2_str
                   }
                 ],
                 "totalCount" => 2
               }
             } = data
    end

    @tag authentication: [
           role: "user",
           permissions: [:approve_grant_request, :view_data_structure]
         ]
    test "list grants filtered by end_date lt", %{conn: conn, domain: %{id: domain_id}} do
      %{id: user_id_1} = CacheHelpers.insert_user()
      ds1 = insert(:data_structure, domain_ids: [domain_id])
      ds2 = insert(:data_structure, domain_ids: [domain_id])
      ds3 = insert(:data_structure, domain_ids: [domain_id])

      start_date_1 = Date.utc_today() |> Date.add(-1)
      end_date_1 = Date.utc_today() |> Date.add(1)

      start_date_2 = Date.utc_today() |> Date.add(-2)
      end_date_2 = Date.utc_today() |> Date.add(2)

      start_date_3 = Date.utc_today() |> Date.add(-3)
      end_date_3 = Date.utc_today() |> Date.add(3)

      %{id: grant_id_1} =
        insert(
          :grant,
          data_structure: ds1,
          user_id: user_id_1,
          start_date: start_date_1,
          end_date: end_date_1
        )

      %{id: grant_id_2} =
        insert(
          :grant,
          data_structure: ds2,
          user_id: user_id_1,
          start_date: start_date_2,
          end_date: end_date_2
        )

      %{id: _grant_id_3} =
        insert(
          :grant,
          data_structure: ds3,
          user_id: user_id_1,
          start_date: start_date_3,
          end_date: end_date_3
        )

      assert %{"data" => data} =
               conn
               |> post(
                 "/api/v2",
                 %{
                   "query" => @grant_query,
                   "variables" => %{
                     "filters" => %{
                       "endDate" => %{
                         "lt" => Date.utc_today() |> Date.add(3) |> to_string
                       }
                     }
                   }
                 }
               )
               |> json_response(:ok)

      grant_id_1_str = "#{grant_id_1}"
      grant_id_2_str = "#{grant_id_2}"

      assert %{
               "grants" => %{
                 "page" => [
                   %{
                     "id" => ^grant_id_2_str
                   },
                   %{
                     "id" => ^grant_id_1_str
                   }
                 ],
                 "totalCount" => 2
               }
             } = data
    end

    @tag authentication: [
           role: "user",
           permissions: [:approve_grant_request, :view_data_structure]
         ]
    test "list grants filtered by end_date eq", %{conn: conn, domain: %{id: domain_id}} do
      %{id: user_id_1} = CacheHelpers.insert_user()
      ds1 = insert(:data_structure, domain_ids: [domain_id])
      ds2 = insert(:data_structure, domain_ids: [domain_id])
      ds3 = insert(:data_structure, domain_ids: [domain_id])

      start_date_1 = Date.utc_today() |> Date.add(-1)
      end_date_1 = Date.utc_today() |> Date.add(1)

      start_date_2 = Date.utc_today() |> Date.add(-2)
      end_date_2 = Date.utc_today() |> Date.add(2)

      start_date_3 = Date.utc_today() |> Date.add(-3)
      end_date_3 = Date.utc_today() |> Date.add(3)

      %{id: grant_id_1} =
        insert(
          :grant,
          data_structure: ds1,
          user_id: user_id_1,
          start_date: start_date_1,
          end_date: end_date_1
        )

      %{id: _grant_id_2} =
        insert(
          :grant,
          data_structure: ds2,
          user_id: user_id_1,
          start_date: start_date_2,
          end_date: end_date_2
        )

      %{id: _grant_id_3} =
        insert(
          :grant,
          data_structure: ds3,
          user_id: user_id_1,
          start_date: start_date_3,
          end_date: end_date_3
        )

      assert %{"data" => data} =
               conn
               |> post(
                 "/api/v2",
                 %{
                   "query" => @grant_query,
                   "variables" => %{
                     "filters" => %{
                       "endDate" => %{
                         "eq" => Date.utc_today() |> Date.add(1) |> to_string
                       }
                     }
                   }
                 }
               )
               |> json_response(:ok)

      grant_id_1_str = "#{grant_id_1}"

      assert %{
               "grants" => %{
                 "page" => [
                   %{
                     "id" => ^grant_id_1_str
                   }
                 ],
                 "totalCount" => 1
               }
             } = data
    end

    @tag authentication: [
           role: "user",
           permissions: [:approve_grant_request, :view_data_structure]
         ]
    test "list grants filtered by end_date gt and lt", %{conn: conn, domain: %{id: domain_id}} do
      %{id: user_id_1} = CacheHelpers.insert_user()
      ds1 = insert(:data_structure, domain_ids: [domain_id])
      ds2 = insert(:data_structure, domain_ids: [domain_id])
      ds3 = insert(:data_structure, domain_ids: [domain_id])

      start_date_1 = Date.utc_today() |> Date.add(-1)
      end_date_1 = Date.utc_today() |> Date.add(1)

      start_date_2 = Date.utc_today() |> Date.add(-2)
      end_date_2 = Date.utc_today() |> Date.add(2)

      start_date_3 = Date.utc_today() |> Date.add(-3)
      end_date_3 = Date.utc_today() |> Date.add(3)

      %{id: _grant_id_1} =
        insert(
          :grant,
          data_structure: ds1,
          user_id: user_id_1,
          start_date: start_date_1,
          end_date: end_date_1
        )

      %{id: grant_id_2} =
        insert(
          :grant,
          data_structure: ds2,
          user_id: user_id_1,
          start_date: start_date_2,
          end_date: end_date_2
        )

      %{id: _grant_id_3} =
        insert(
          :grant,
          data_structure: ds3,
          user_id: user_id_1,
          start_date: start_date_3,
          end_date: end_date_3
        )

      assert %{"data" => data} =
               conn
               |> post(
                 "/api/v2",
                 %{
                   "query" => @grant_query,
                   "variables" => %{
                     "filters" => %{
                       "endDate" => %{
                         "lt" => Date.utc_today() |> Date.add(3) |> to_string,
                         "gt" => Date.utc_today() |> Date.add(1) |> to_string
                       }
                     }
                   }
                 }
               )
               |> json_response(:ok)

      grant_id_2_str = "#{grant_id_2}"

      assert %{
               "grants" => %{
                 "page" => [
                   %{
                     "id" => ^grant_id_2_str
                   }
                 ],
                 "totalCount" => 1
               }
             } = data
    end

    @tag authentication: [
           role: "user",
           permissions: [:approve_grant_request, :view_data_structure]
         ]
    test "list grants filtered by inserted_at gt", %{conn: conn, domain: %{id: domain_id}} do
      %{id: user_id_1} = CacheHelpers.insert_user()
      ds1 = insert(:data_structure, domain_ids: [domain_id])
      ds2 = insert(:data_structure, domain_ids: [domain_id])
      ds3 = insert(:data_structure, domain_ids: [domain_id])

      inserted_at_1 = DateTime.utc_now() |> DateTime.add(-1 * 3600 * 24)

      inserted_at_2 = DateTime.utc_now() |> DateTime.add(-2 * 3600 * 24)

      inserted_at_3 = DateTime.utc_now() |> DateTime.add(-3 * 3600 * 24)

      %{id: grant_id_1} =
        insert(
          :grant,
          data_structure: ds1,
          user_id: user_id_1,
          inserted_at: inserted_at_1
        )

      %{id: grant_id_2} =
        insert(
          :grant,
          data_structure: ds2,
          user_id: user_id_1,
          inserted_at: inserted_at_2
        )

      %{id: _grant_id_3} =
        insert(
          :grant,
          data_structure: ds3,
          user_id: user_id_1,
          inserted_at: inserted_at_3
        )

      assert %{"data" => data} =
               conn
               |> post(
                 "/api/v2",
                 %{
                   "query" => @grant_query,
                   "variables" => %{
                     "filters" => %{
                       "insertedAt" => %{
                         "gt" => Date.utc_today() |> Date.add(-3) |> to_string
                       }
                     }
                   }
                 }
               )
               |> json_response(:ok)

      grant_id_1_str = "#{grant_id_1}"
      grant_id_2_str = "#{grant_id_2}"

      assert %{
               "grants" => %{
                 "page" => [
                   %{
                     "id" => ^grant_id_2_str
                   },
                   %{
                     "id" => ^grant_id_1_str
                   }
                 ],
                 "totalCount" => 2
               }
             } = data
    end

    @tag authentication: [
           role: "user",
           permissions: [:approve_grant_request, :view_data_structure]
         ]
    test "list grants filtered by inserted_at lt", %{conn: conn, domain: %{id: domain_id}} do
      %{id: user_id_1} = CacheHelpers.insert_user()
      ds1 = insert(:data_structure, domain_ids: [domain_id])
      ds2 = insert(:data_structure, domain_ids: [domain_id])
      ds3 = insert(:data_structure, domain_ids: [domain_id])

      inserted_at_1 = DateTime.utc_now() |> DateTime.add(-1 * 3600 * 24)

      inserted_at_2 = DateTime.utc_now() |> DateTime.add(-2 * 3600 * 24)

      inserted_at_3 = DateTime.utc_now() |> DateTime.add(-3 * 3600 * 24)

      %{id: _grant_id_1} =
        insert(
          :grant,
          data_structure: ds1,
          user_id: user_id_1,
          inserted_at: inserted_at_1
        )

      %{id: grant_id_2} =
        insert(
          :grant,
          data_structure: ds2,
          user_id: user_id_1,
          inserted_at: inserted_at_2
        )

      %{id: grant_id_3} =
        insert(
          :grant,
          data_structure: ds3,
          user_id: user_id_1,
          inserted_at: inserted_at_3
        )

      assert %{"data" => data} =
               conn
               |> post(
                 "/api/v2",
                 %{
                   "query" => @grant_query,
                   "variables" => %{
                     "filters" => %{
                       "insertedAt" => %{
                         "lt" => Date.utc_today() |> Date.add(-1) |> to_string
                       }
                     }
                   }
                 }
               )
               |> json_response(:ok)

      grant_id_2_str = "#{grant_id_2}"
      grant_id_3_str = "#{grant_id_3}"

      assert %{
               "grants" => %{
                 "page" => [
                   %{
                     "id" => ^grant_id_3_str
                   },
                   %{
                     "id" => ^grant_id_2_str
                   }
                 ],
                 "totalCount" => 2
               }
             } = data
    end

    @tag authentication: [
           role: "user",
           permissions: [:approve_grant_request, :view_data_structure]
         ]
    test "list grants filtered by inserted_at eq", %{conn: conn, domain: %{id: domain_id}} do
      %{id: user_id_1} = CacheHelpers.insert_user()
      ds1 = insert(:data_structure, domain_ids: [domain_id])
      ds2 = insert(:data_structure, domain_ids: [domain_id])
      ds3 = insert(:data_structure, domain_ids: [domain_id])

      inserted_at_1 = DateTime.utc_now() |> DateTime.add(-1 * 3600 * 24)

      inserted_at_2 = DateTime.utc_now() |> DateTime.add(-2 * 3600 * 24)

      inserted_at_3 = DateTime.utc_now() |> DateTime.add(-3 * 3600 * 24)

      %{id: grant_id_1} =
        insert(
          :grant,
          data_structure: ds1,
          user_id: user_id_1,
          inserted_at: inserted_at_1
        )

      %{id: _grant_id_2} =
        insert(
          :grant,
          data_structure: ds2,
          user_id: user_id_1,
          inserted_at: inserted_at_2
        )

      %{id: _grant_id_3} =
        insert(
          :grant,
          data_structure: ds3,
          user_id: user_id_1,
          inserted_at: inserted_at_3
        )

      assert %{"data" => data} =
               conn
               |> post(
                 "/api/v2",
                 %{
                   "query" => @grant_query,
                   "variables" => %{
                     "filters" => %{
                       "insertedAt" => %{
                         "eq" => Date.utc_today() |> Date.add(-1) |> to_string
                       }
                     }
                   }
                 }
               )
               |> json_response(:ok)

      grant_id_1_str = "#{grant_id_1}"

      assert %{
               "grants" => %{
                 "page" => [
                   %{
                     "id" => ^grant_id_1_str
                   }
                 ],
                 "totalCount" => 1
               }
             } = data
    end

    @tag authentication: [
           role: "user",
           permissions: [:approve_grant_request, :view_data_structure]
         ]
    test "list grants filtered by inserted_at gt and lt", %{conn: conn, domain: %{id: domain_id}} do
      %{id: user_id_1} = CacheHelpers.insert_user()
      ds1 = insert(:data_structure, domain_ids: [domain_id])
      ds2 = insert(:data_structure, domain_ids: [domain_id])
      ds3 = insert(:data_structure, domain_ids: [domain_id])

      inserted_at_1 = DateTime.utc_now() |> DateTime.add(-1 * 3600 * 24)

      inserted_at_2 = DateTime.utc_now() |> DateTime.add(-2 * 3600 * 24)

      inserted_at_3 = DateTime.utc_now() |> DateTime.add(-3 * 3600 * 24)

      %{id: _grant_id_1} =
        insert(
          :grant,
          data_structure: ds1,
          user_id: user_id_1,
          inserted_at: inserted_at_1
        )

      %{id: grant_id_2} =
        insert(
          :grant,
          data_structure: ds2,
          user_id: user_id_1,
          inserted_at: inserted_at_2
        )

      %{id: _grant_id_3} =
        insert(
          :grant,
          data_structure: ds3,
          user_id: user_id_1,
          inserted_at: inserted_at_3
        )

      assert %{"data" => data} =
               conn
               |> post(
                 "/api/v2",
                 %{
                   "query" => @grant_query,
                   "variables" => %{
                     "filters" => %{
                       "insertedAt" => %{
                         "gt" => Date.utc_today() |> Date.add(-3) |> to_string,
                         "lt" => Date.utc_today() |> Date.add(-1) |> to_string
                       }
                     }
                   }
                 }
               )
               |> json_response(:ok)

      grant_id_2_str = "#{grant_id_2}"

      assert %{
               "grants" => %{
                 "page" => [
                   %{
                     "id" => ^grant_id_2_str
                   }
                 ],
                 "totalCount" => 1
               }
             } = data
    end

    @tag authentication: [
           role: "user",
           permissions: [:approve_grant_request, :view_data_structure]
         ]
    test "list grants filtered by updated_at gt", %{conn: conn, domain: %{id: domain_id}} do
      %{id: user_id_1} = CacheHelpers.insert_user()
      ds1 = insert(:data_structure, domain_ids: [domain_id])
      ds2 = insert(:data_structure, domain_ids: [domain_id])
      ds3 = insert(:data_structure, domain_ids: [domain_id])

      updated_at_1 = DateTime.utc_now() |> DateTime.add(-1 * 3600 * 24)

      updated_at_2 = DateTime.utc_now() |> DateTime.add(-2 * 3600 * 24)

      updated_at_3 = DateTime.utc_now() |> DateTime.add(-3 * 3600 * 24)

      %{id: grant_id_1} =
        insert(
          :grant,
          data_structure: ds1,
          user_id: user_id_1,
          updated_at: updated_at_1
        )

      %{id: grant_id_2} =
        insert(
          :grant,
          data_structure: ds2,
          user_id: user_id_1,
          updated_at: updated_at_2
        )

      %{id: _grant_id_3} =
        insert(
          :grant,
          data_structure: ds3,
          user_id: user_id_1,
          updated_at: updated_at_3
        )

      assert %{"data" => data} =
               conn
               |> post(
                 "/api/v2",
                 %{
                   "query" => @grant_query,
                   "variables" => %{
                     "filters" => %{
                       "updatedAt" => %{
                         "gt" => Date.utc_today() |> Date.add(-3) |> to_string
                       }
                     }
                   }
                 }
               )
               |> json_response(:ok)

      grant_id_1_str = "#{grant_id_1}"
      grant_id_2_str = "#{grant_id_2}"

      assert %{
               "grants" => %{
                 "page" => [
                   %{
                     "id" => ^grant_id_2_str
                   },
                   %{
                     "id" => ^grant_id_1_str
                   }
                 ],
                 "totalCount" => 2
               }
             } = data
    end

    @tag authentication: [
           role: "user",
           permissions: [:approve_grant_request, :view_data_structure]
         ]
    test "list grants filtered by updated_at lt", %{conn: conn, domain: %{id: domain_id}} do
      %{id: user_id_1} = CacheHelpers.insert_user()
      ds1 = insert(:data_structure, domain_ids: [domain_id])
      ds2 = insert(:data_structure, domain_ids: [domain_id])
      ds3 = insert(:data_structure, domain_ids: [domain_id])

      updated_at_1 = DateTime.utc_now() |> DateTime.add(-1 * 3600 * 24)

      updated_at_2 = DateTime.utc_now() |> DateTime.add(-2 * 3600 * 24)

      updated_at_3 = DateTime.utc_now() |> DateTime.add(-3 * 3600 * 24)

      %{id: _grant_id_1} =
        insert(
          :grant,
          data_structure: ds1,
          user_id: user_id_1,
          updated_at: updated_at_1
        )

      %{id: grant_id_2} =
        insert(
          :grant,
          data_structure: ds2,
          user_id: user_id_1,
          updated_at: updated_at_2
        )

      %{id: grant_id_3} =
        insert(
          :grant,
          data_structure: ds3,
          user_id: user_id_1,
          updated_at: updated_at_3
        )

      assert %{"data" => data} =
               conn
               |> post(
                 "/api/v2",
                 %{
                   "query" => @grant_query,
                   "variables" => %{
                     "filters" => %{
                       "updatedAt" => %{
                         "lt" => Date.utc_today() |> Date.add(-1) |> to_string
                       }
                     }
                   }
                 }
               )
               |> json_response(:ok)

      grant_id_2_str = "#{grant_id_2}"
      grant_id_3_str = "#{grant_id_3}"

      assert %{
               "grants" => %{
                 "page" => [
                   %{
                     "id" => ^grant_id_3_str
                   },
                   %{
                     "id" => ^grant_id_2_str
                   }
                 ],
                 "totalCount" => 2
               }
             } = data
    end

    @tag authentication: [
           role: "user",
           permissions: [:approve_grant_request, :view_data_structure]
         ]
    test "list grants filtered by updated_at eq", %{conn: conn, domain: %{id: domain_id}} do
      %{id: user_id_1} = CacheHelpers.insert_user()
      ds1 = insert(:data_structure, domain_ids: [domain_id])
      ds2 = insert(:data_structure, domain_ids: [domain_id])
      ds3 = insert(:data_structure, domain_ids: [domain_id])

      updated_at_1 = DateTime.utc_now() |> DateTime.add(-1 * 3600 * 24)

      updated_at_2 = DateTime.utc_now() |> DateTime.add(-2 * 3600 * 24)

      updated_at_3 = DateTime.utc_now() |> DateTime.add(-3 * 3600 * 24)

      %{id: grant_id_1} =
        insert(
          :grant,
          data_structure: ds1,
          user_id: user_id_1,
          updated_at: updated_at_1
        )

      %{id: _grant_id_2} =
        insert(
          :grant,
          data_structure: ds2,
          user_id: user_id_1,
          updated_at: updated_at_2
        )

      %{id: _grant_id_3} =
        insert(
          :grant,
          data_structure: ds3,
          user_id: user_id_1,
          updated_at: updated_at_3
        )

      assert %{"data" => data} =
               conn
               |> post(
                 "/api/v2",
                 %{
                   "query" => @grant_query,
                   "variables" => %{
                     "filters" => %{
                       "updatedAt" => %{
                         "eq" => Date.utc_today() |> Date.add(-1) |> to_string
                       }
                     }
                   }
                 }
               )
               |> json_response(:ok)

      grant_id_1_str = "#{grant_id_1}"

      assert %{
               "grants" => %{
                 "page" => [
                   %{
                     "id" => ^grant_id_1_str
                   }
                 ],
                 "totalCount" => 1
               }
             } = data
    end

    @tag authentication: [
           role: "user",
           permissions: [:approve_grant_request, :view_data_structure]
         ]
    test "list grants filtered by updated_at gt and lt", %{conn: conn, domain: %{id: domain_id}} do
      %{id: user_id_1} = CacheHelpers.insert_user()
      ds1 = insert(:data_structure, domain_ids: [domain_id])
      ds2 = insert(:data_structure, domain_ids: [domain_id])
      ds3 = insert(:data_structure, domain_ids: [domain_id])

      updated_at_1 = DateTime.utc_now() |> DateTime.add(-1 * 3600 * 24)

      updated_at_2 = DateTime.utc_now() |> DateTime.add(-2 * 3600 * 24)

      updated_at_3 = DateTime.utc_now() |> DateTime.add(-3 * 3600 * 24)

      %{id: _grant_id_1} =
        insert(
          :grant,
          data_structure: ds1,
          user_id: user_id_1,
          updated_at: updated_at_1
        )

      %{id: grant_id_2} =
        insert(
          :grant,
          data_structure: ds2,
          user_id: user_id_1,
          updated_at: updated_at_2
        )

      %{id: _grant_id_3} =
        insert(
          :grant,
          data_structure: ds3,
          user_id: user_id_1,
          updated_at: updated_at_3
        )

      assert %{"data" => data} =
               conn
               |> post(
                 "/api/v2",
                 %{
                   "query" => @grant_query,
                   "variables" => %{
                     "filters" => %{
                       "updatedAt" => %{
                         "gt" => Date.utc_today() |> Date.add(-3) |> to_string,
                         "lt" => Date.utc_today() |> Date.add(-1) |> to_string
                       }
                     }
                   }
                 }
               )
               |> json_response(:ok)

      grant_id_2_str = "#{grant_id_2}"

      assert %{
               "grants" => %{
                 "page" => [
                   %{
                     "id" => ^grant_id_2_str
                   }
                 ],
                 "totalCount" => 1
               }
             } = data
    end

    # Test grants pagination

    @tag authentication: [
           role: "user",
           permissions: [:approve_grant_request, :view_data_structure]
         ]
    test "list grants paginated by firts and after", %{conn: conn, domain: %{id: domain_id}} do
      %{id: user_id} = CacheHelpers.insert_user()

      grant_ids =
        Enum.map(1..10, fn _ ->
          %{id: id} =
            insert(
              :grant,
              data_structure: insert(:data_structure, domain_ids: [domain_id]),
              user_id: user_id
            )

          %{"id" => id}
        end)

      [page | pages] =
        grant_ids
        |> Enum.map(fn %{"id" => id} -> %{"id" => to_string(id)} end)
        |> Enum.chunk_every(4)
        |> Enum.map(&Enum.sort_by(&1, fn %{"id" => id} -> Integer.parse(id) end, :desc))

      assert %{
               "data" => %{
                 "grants" => %{
                   "page" => ^page,
                   "pageInfo" => %{
                     "endCursor" => end_cursor,
                     "hasNextPage" => true,
                     "hasPreviousPage" => false
                   },
                   "totalCount" => 10
                 }
               }
             } =
               conn
               |> post(
                 "/api/v2",
                 %{
                   "query" => @paginate_grant_query,
                   "variables" => %{
                     "first" => 4
                   }
                 }
               )
               |> json_response(:ok)

      [page | [last_page]] = pages

      assert %{
               "data" => %{
                 "grants" => %{
                   "page" => ^page,
                   "pageInfo" => %{
                     "endCursor" => end_cursor,
                     "hasNextPage" => true,
                     "hasPreviousPage" => true
                   },
                   "totalCount" => 10
                 }
               }
             } =
               conn
               |> post(
                 "/api/v2",
                 %{
                   "query" => @paginate_grant_query,
                   "variables" => %{
                     "first" => 4,
                     "after" => end_cursor
                   }
                 }
               )
               |> json_response(:ok)

      assert %{
               "data" => %{
                 "grants" => %{
                   "page" => ^last_page,
                   "pageInfo" => %{
                     "hasNextPage" => false,
                     "hasPreviousPage" => true
                   },
                   "totalCount" => 10
                 }
               }
             } =
               conn
               |> post(
                 "/api/v2",
                 %{
                   "query" => @paginate_grant_query,
                   "variables" => %{
                     "first" => 4,
                     "after" => end_cursor
                   }
                 }
               )
               |> json_response(:ok)
    end

    @tag authentication: [
           role: "user",
           permissions: [:approve_grant_request, :view_data_structure]
         ]
    test "list grants paginated by last and before", %{conn: conn, domain: %{id: domain_id}} do
      %{id: user_id} = CacheHelpers.insert_user()

      grant_ids =
        Enum.map(1..10, fn _ ->
          %{id: id} =
            insert(
              :grant,
              data_structure: insert(:data_structure, domain_ids: [domain_id]),
              user_id: user_id
            )

          %{"id" => id}
        end)

      [page | pages] =
        grant_ids
        |> Enum.map(fn %{"id" => id} -> %{"id" => to_string(id)} end)
        |> Enum.reverse()
        |> Enum.chunk_every(4)

      assert %{
               "data" => %{
                 "grants" => %{
                   "page" => ^page,
                   "pageInfo" => %{
                     "startCursor" => start_cursor,
                     "hasNextPage" => false,
                     "hasPreviousPage" => true
                   },
                   "totalCount" => 10
                 }
               }
             } =
               conn
               |> post(
                 "/api/v2",
                 %{
                   "query" => @paginate_grant_query,
                   "variables" => %{
                     "last" => 4
                   }
                 }
               )
               |> json_response(:ok)

      [page | [last_page]] = pages

      assert %{
               "data" => %{
                 "grants" => %{
                   "page" => ^page,
                   "pageInfo" => %{
                     "startCursor" => start_cursor,
                     "hasNextPage" => true,
                     "hasPreviousPage" => true
                   },
                   "totalCount" => 10
                 }
               }
             } =
               conn
               |> post(
                 "/api/v2",
                 %{
                   "query" => @paginate_grant_query,
                   "variables" => %{
                     "last" => 4,
                     "before" => start_cursor
                   }
                 }
               )
               |> json_response(:ok)

      assert %{
               "data" => %{
                 "grants" => %{
                   "page" => ^last_page,
                   "pageInfo" => %{
                     "hasNextPage" => true,
                     "hasPreviousPage" => false
                   },
                   "totalCount" => 10
                 }
               }
             } =
               conn
               |> post(
                 "/api/v2",
                 %{
                   "query" => @paginate_grant_query,
                   "variables" => %{
                     "last" => 4,
                     "before" => start_cursor
                   }
                 }
               )
               |> json_response(:ok)
    end
  end
end
