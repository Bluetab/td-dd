defmodule TdDdWeb.ImplementationUploadControllerTest do
  use TdDqWeb.ConnCase

  alias TdDq.Implementations
  alias TdDq.Implementations.Implementation

  @moduletag sandbox: :shared

  setup_all do
    start_supervised!(TdDd.Search.MockIndexWorker)
    :ok
  end

  setup context do
    template = CacheHelpers.insert_template(scope: "dq", name: "bar_template")
    rule = insert_rule(context)

    [template: template, rule: rule]
  end

  # This domain comes from TdDqWeb.ConnCase setup tags if
  # @tag authentication with permissions is used
  defp insert_rule(%{domain: %{id: domain_id}}) do
    insert(:rule, name: "rule_foo", domain_id: domain_id)
  end

  defp insert_rule(_context_without_domain) do
    insert(:rule, name: "rule_foo")
  end

  describe "upload" do
    @tag authentication: [role: "admin"]
    test "uploads implementations", %{conn: conn} do
      attrs = %{
        implementations: %Plug.Upload{
          filename: "implementations.csv",
          path: "test/fixtures/implementations/implementations.csv"
        }
      }

      assert %{"data" => data} =
               conn
               |> post(Routes.implementation_upload_path(conn, :create), attrs)
               |> json_response(:ok)

      assert %{"ids" => ids, "errors" => []} = data
      assert length(ids) == 3
    end

    for status <- ["deprecated", "pending_approval", "versioned"] do
      @tag authentication: [role: "admin"]
      @tag status: status
      test "uploads #{status} implementation returns error", %{
        conn: conn,
        status: status
      } do
        insert(
          :implementation,
          implementation_key: "boo_key_1",
          status: status
        )

        attrs = %{
          implementations: %Plug.Upload{
            filename: "implementations.csv",
            path: "test/fixtures/implementations/implementations.csv"
          }
        }

        assert %{"data" => data} =
                 conn
                 |> post(Routes.implementation_upload_path(conn, :create), attrs)
                 |> json_response(:ok)

        assert %{
                 "ids" => ids,
                 "errors" => errors
               } = data

        assert length(ids) == 2

        assert [
                 %{
                   "implementation_key" => "boo_key_1",
                   "message" => %{"implementation" => [^status]}
                 }
               ] = errors
      end
    end

    @tag authentication: [role: "user"]
    test "return error if user has no permissions", %{conn: conn} do
      attrs = %{
        implementations: %Plug.Upload{
          filename: "implementations.csv",
          path: "test/fixtures/implementations/implementations.csv"
        }
      }

      assert %{"data" => data} =
               conn
               |> post(Routes.implementation_upload_path(conn, :create), attrs)
               |> json_response(:ok)

      assert %{"ids" => [], "errors" => errors} = data
      assert length(errors) == 3

      Enum.each(errors, fn %{"message" => message} ->
        assert ^message = %{"implementation" => ["forbidden"]}
      end)
    end

    @tag authentication: [role: "user", permissions: [:manage_basic_implementations]]
    test "user with permissions: update and create implementations with rule", %{
      conn: conn,
      rule: rule
    } do
      # Override factory with:
      #   segments empty list so that :manage_segments is not needed
      #   basic implementation type so that :manage_quality_rule_implementations is not needed
      # Implementation to be updated in the CSV upload
      insert(
        :implementation,
        implementation_key: "boo_key_1",
        implementation_type: "basic",
        rule_id: rule.id,
        domain_id: rule.domain_id,
        status: :draft,
        version: 1,
        minimum: 10,
        goal: 20,
        segments: []
      )

      attrs = %{
        implementations: %Plug.Upload{
          filename: "implementations.csv",
          path: "test/fixtures/implementations/implementations.csv"
        }
      }

      assert %{"data" => data} =
               conn
               |> post(Routes.implementation_upload_path(conn, :create), attrs)
               |> json_response(:ok)

      assert %{"ids" => ids, "errors" => []} = data
      assert length(ids) == 3
    end

    @tag authentication: [role: "user", permissions: [:manage_basic_implementations]]
    test "user cannot publish implementations with rule if it lacks publish permission", %{
      conn: conn
    } do
      attrs = %{
        "implementations" => %Plug.Upload{
          filename: "implementations.csv",
          path: "test/fixtures/implementations/implementations.csv"
        },
        "auto_publish" => "true"
      }

      assert %{"data" => data} =
               conn
               |> post(Routes.implementation_upload_path(conn, :create), attrs)
               |> json_response(:ok)

      assert %{"ids" => [], "errors" => errors} = data
      assert length(errors) == 3

      Enum.each(errors, fn %{"message" => message} ->
        assert ^message = %{"implementation" => ["forbidden"]}
      end)
    end

    @tag authentication: [
           role: "user",
           permissions: [
             :manage_basic_implementations,
             :manage_ruleless_implementations,
             :publish_implementation
           ],
           domain_params: %{external_id: "some_domain_id"}
         ]
    test "should version previously published versions before publishing current draft", %{
      conn: conn,
      rule: rule,
      domain: %{id: domain_id}
    } do
      assert rule.domain_id == domain_id

      %{id: implementation_boo_key_version_1_id, implementation_ref: implementation_ref} =
        insert(
          :implementation,
          implementation_key: "boo_key_1",
          df_content: %{string: "boo_1"},
          implementation_type: "basic",
          rule_id: rule.id,
          domain_id: rule.domain_id,
          status: :published,
          version: 1,
          minimum: 10,
          goal: 11,
          segments: []
        )

      %{id: implementation_boo_key_version_2_id} =
        insert(
          :implementation,
          implementation_key: "boo_key_1",
          implementation_ref: implementation_ref,
          df_content: %{string: "boo_1"},
          implementation_type: "basic",
          rule_id: rule.id,
          domain_id: rule.domain_id,
          status: :draft,
          version: 2,
          minimum: 12,
          goal: 13,
          segments: []
        )

      attrs = %{
        "implementations" => %Plug.Upload{
          filename: "one_implementation.csv",
          path: "test/fixtures/implementations/one_implementation.csv"
        },
        "auto_publish" => "true"
      }

      assert %{"data" => data} =
               conn
               |> post(Routes.implementation_upload_path(conn, :create), attrs)
               |> json_response(:ok)

      assert %{"ids" => ids, "errors" => []} = data

      assert %Implementation{
               id: ^implementation_boo_key_version_1_id,
               implementation_key: "boo_key_1",
               df_content: %{"string" => "boo_1"},
               status: :versioned,
               minimum: 10.0,
               goal: 11.0
             } = TdDq.Implementations.get_implementation(implementation_boo_key_version_1_id)

      uploaded_implementations = Enum.map(ids, &TdDq.Implementations.get_implementation(&1))

      assert [
               %Implementation{
                 id: ^implementation_boo_key_version_2_id,
                 implementation_key: "boo_key_1",
                 df_content: %{"string" => "boo_1_from_csv"},
                 status: :published,
                 minimum: 14.0,
                 goal: 15.0
               }
             ] = uploaded_implementations
    end

    @tag authentication: [
           role: "user",
           permissions: [
             :manage_basic_implementations,
             :manage_quality_rule_implementations,
             :manage_ruleless_implementations,
             :publish_implementation
           ],
           domain_params: %{external_id: "some_domain_id"}
         ]
    test "user with permissions: update and create implementations with rule, publish", %{
      conn: conn,
      rule: rule,
      domain: %{id: domain_id}
    } do
      assert rule.domain_id == domain_id

      # Override factory with:
      #   segments empty list so that :manage_segments is not needed
      # Implementations to be updated in the CSV upload

      # Implementations with rules
      # One in draft status
      %{id: implementation_boo_key_1_id} =
        insert(
          :implementation,
          implementation_key: "boo_key_1",
          df_content: %{string: "boo_1"},
          implementation_type: "basic",
          rule_id: rule.id,
          domain_id: rule.domain_id,
          status: :draft,
          version: 1,
          minimum: 10,
          goal: 20,
          segments: []
        )

      # The other one in published status
      %{id: implementation_boo_key_2_id} =
        insert(
          :implementation,
          implementation_key: "boo_key_2",
          df_content: %{string: "boo_2"},
          implementation_type: "basic",
          rule_id: rule.id,
          domain_id: rule.domain_id,
          status: :published,
          version: 1,
          minimum: 10,
          goal: 20,
          segments: []
        )

      # Implementations without rules
      %{id: implementation_boo_key_4_id} =
        insert(
          :implementation,
          implementation_key: "boo_key_4",
          implementation_type: "basic",
          domain_id: domain_id,
          df_content: %{string: "boo_4"},
          status: :draft,
          version: 1,
          minimum: 10,
          goal: 20,
          segments: []
        )

      # The other one in published status
      %{id: implementation_boo_key_5_id, updated_at: updated_date} =
        insert(
          :implementation,
          implementation_key: "boo_key_5",
          implementation_type: "basic",
          df_content: %{string: "boo_5"},
          domain_id: domain_id,
          status: :published,
          implementation_type: "default",
          version: 1,
          minimum: 10,
          goal: 20,
          segments: []
        )

      attrs = %{
        "implementations" => %Plug.Upload{
          filename: "implementations_with_and_without_rules.csv",
          path: "test/fixtures/implementations/implementations_with_and_without_rules.csv"
        },
        "auto_publish" => "true"
      }

      assert %{"data" => data} =
               conn
               |> post(Routes.implementation_upload_path(conn, :create), attrs)
               |> json_response(:ok)

      assert %{"ids" => ids, "errors" => errors} = data
      assert length(ids) == 6

      assert [
               %{
                 "implementation_key" => "boo_key_7",
                 "message" => %{
                   "domain_external_id" => [
                     "Domain with external id other_domain_id doesn't exist"
                   ]
                 }
               }
             ] == errors

      uploaded_implementations = Enum.map(ids, &TdDq.Implementations.get_implementation(&1))
      # This one was in draft and has been updated, so it still has the same id
      assert %Implementation{
               id: ^implementation_boo_key_1_id,
               implementation_key: "boo_key_1",
               df_content: %{"string" => "boo_1_from_csv"},
               status: :published,
               minimum: 11.0,
               goal: 12.0
             } = Enum.find(uploaded_implementations, &(&1.implementation_key == "boo_key_1"))

      # This one was already published and has been updated, so:
      #   New Implemementation inserted as "published"...
      assert %Implementation{
               implementation_key: "boo_key_2",
               df_content: %{"string" => "boo_2_from_csv"},
               status: :published,
               minimum: 22.0,
               goal: 23.0
             } = Enum.find(uploaded_implementations, &(&1.implementation_key == "boo_key_2"))

      #   ...and previously published one is now versioned
      assert %Implementation{
               id: ^implementation_boo_key_2_id,
               implementation_key: "boo_key_2",
               df_content: %{"string" => "boo_2"},
               status: :versioned,
               version: 1,
               minimum: 10.0,
               goal: 20.0
             } = Implementations.get_implementation(implementation_boo_key_2_id)

      # This one is new
      assert %Implementation{
               implementation_key: "boo_key_3",
               df_content: %{"string" => "boo_3_from_csv"},
               status: :published,
               minimum: 33.0,
               goal: 34.0
             } = Enum.find(uploaded_implementations, &(&1.implementation_key == "boo_key_3"))

      # This one was in draft and has been updated, so it still has the same id
      assert %Implementation{
               id: ^implementation_boo_key_4_id,
               implementation_key: "boo_key_4",
               df_content: %{"string" => "boo_4_from_csv"},
               status: :published,
               minimum: 145.0,
               goal: 144.0
             } = Enum.find(uploaded_implementations, &(&1.implementation_key == "boo_key_4"))

      # This one was already published and has been updated, so:
      #   New Implemementation inserted as "published"...
      assert %Implementation{
               implementation_key: "boo_key_5",
               df_content: %{"string" => "boo_5_from_csv"},
               status: :published,
               implementation_type: "default",
               minimum: 156.0,
               goal: 155.0,
               updated_at: updated_at_recover
             } = Enum.find(uploaded_implementations, &(&1.implementation_key == "boo_key_5"))

      refute updated_at_recover == updated_date

      #   ...and previously published one is now versioned
      assert %Implementation{
               id: ^implementation_boo_key_5_id,
               implementation_key: "boo_key_5",
               df_content: %{"string" => "boo_5"},
               status: :versioned,
               implementation_type: "default",
               version: 1,
               minimum: 10.0,
               goal: 20.0,
               updated_at: updated_at_recover2
             } = Implementations.get_implementation(implementation_boo_key_5_id)

      refute updated_at_recover2 == updated_date

      # This one is new
      assert %Implementation{
               implementation_key: "boo_key_6",
               df_content: %{"string" => "boo_6_from_csv"},
               status: :published,
               implementation_type: "basic",
               minimum: 167.0,
               goal: 166.0
             } = Enum.find(uploaded_implementations, &(&1.implementation_key == "boo_key_6"))
    end

    @tag authentication: [role: "admin"]
    test "uploads implementations with domain selection template", %{conn: conn} do
      attrs = %{
        implementations: %Plug.Upload{
          filename: "implementations.csv",
          path: "test/fixtures/implementations/implementations_template_with_domain.csv"
        }
      }

      %{id: domain_id1} = CacheHelpers.insert_domain(external_id: "domain_external_id1")
      %{id: domain_id2} = CacheHelpers.insert_domain(external_id: "domain_external_id2")

      template_content = [
        %{
          "fields" => [
            %{
              "name" => "my_domain1",
              "type" => "domain",
              "label" => "My domain",
              "values" => nil,
              "widget" => "dropdown",
              "default" => "",
              "cardinality" => "?",
              "subscribable" => false
            },
            %{
              "name" => "my_domain2",
              "type" => "domain",
              "label" => "My domain2",
              "values" => nil,
              "widget" => "dropdown",
              "default" => "",
              "cardinality" => "?",
              "subscribable" => false
            }
          ],
          "name" => "group_name0"
        }
      ]

      CacheHelpers.insert_template(
        scope: "ri",
        content: template_content,
        name: "domain_template"
      )

      assert %{"data" => data} =
               conn
               |> post(Routes.implementation_upload_path(conn, :create), attrs)
               |> json_response(:ok)

      assert %{"ids" => [id1, id2, id3], "errors" => []} = data

      assert %{
               "data" => %{
                 "df_content" => df_content
               }
             } =
               conn
               |> get(Routes.implementation_path(conn, :show, id1))
               |> json_response(:ok)

      assert %{"my_domain1" => ^domain_id1, "my_domain2" => ^domain_id2} = df_content

      assert %{
               "data" => %{
                 "df_content" => df_content2
               }
             } =
               conn
               |> get(Routes.implementation_path(conn, :show, id2))
               |> json_response(:ok)

      assert %{"my_domain1" => ^domain_id1, "my_domain2" => nil} = df_content2

      assert %{
               "data" => %{
                 "df_content" => df_content3
               }
             } =
               conn
               |> get(Routes.implementation_path(conn, :show, id3))
               |> json_response(:ok)

      assert %{"my_domain1" => nil, "my_domain2" => nil} = df_content3
    end

    @tag authentication: [role: "admin"]
    test "uploads implementations with template with enriched text", %{conn: conn} do
      attrs = %{
        implementations: %Plug.Upload{
          filename: "implementations.csv",
          path: "test/fixtures/implementations/implementations_template_with_enriched_text.csv"
        }
      }

      template_content = [
        %{
          "fields" => [
            %{
              "name" => "enriched_field",
              "type" => "enriched_text",
              "label" => "Enriched field",
              "values" => nil,
              "widget" => "enriched_text",
              "default" => "",
              "cardinality" => "?",
              "subscribable" => false
            }
          ],
          "name" => "group_name0"
        }
      ]

      CacheHelpers.insert_template(
        scope: "ri",
        content: template_content,
        name: "enriched_template"
      )

      assert %{"data" => data} =
               conn
               |> post(Routes.implementation_upload_path(conn, :create), attrs)
               |> json_response(:ok)

      assert %{"ids" => [id1, id2], "errors" => []} = data

      assert %{
               "data" => %{
                 "df_content" => df_content
               }
             } =
               conn
               |> get(Routes.implementation_path(conn, :show, id1))
               |> json_response(:ok)

      assert %{
               "enriched_field" => %{
                 "document" => %{
                   "nodes" => [
                     %{
                       "nodes" => [%{"object" => "text", "leaves" => [%{"text" => "foo"}]}],
                       "object" => "block",
                       "type" => "paragraph"
                     }
                   ]
                 }
               }
             } = df_content

      assert %{
               "data" => %{
                 "df_content" => df_content2
               }
             } =
               conn
               |> get(Routes.implementation_path(conn, :show, id2))
               |> json_response(:ok)

      assert %{"enriched_field" => %{}} = df_content2
    end

    @tag authentication: [role: "admin"]
    test "upload implementations in native language", %{conn: conn} do
      attrs = %{
        implementations: %Plug.Upload{
          filename: "implementations_translations.csv",
          path: "test/fixtures/implementations/implementations_translations.csv"
        },
        lang: "es"
      }

      template_content = [
        %{
          "fields" => [
            %{
              "cardinality" => "1",
              "label" => "label_i18n",
              "name" => "i18n",
              "type" => "string",
              "values" => %{"fixed" => ["one", "two", "three"]}
            }
          ],
          "name" => "group_name0"
        }
      ]

      CacheHelpers.insert_template(
        name: "i18n_template",
        scope: "ri",
        content: template_content
      )

      CacheHelpers.put_i18n_message("es", %{
        message_id: "fields.label_i18n.one",
        definition: "uno"
      })

      CacheHelpers.put_i18n_message("es", %{
        message_id: "fields.label_i18n.two",
        definition: "dos"
      })

      CacheHelpers.put_i18n_message("es", %{
        message_id: "fields.label_i18n.three",
        definition: "tres"
      })

      CacheHelpers.put_i18n_message("es", %{
        message_id: "ruleImplementations.props.result_type.deviation",
        definition: "Desviación"
      })

      CacheHelpers.put_i18n_message("es", %{
        message_id: "ruleImplementations.props.result_type.errors_number",
        definition: "Número"
      })

      CacheHelpers.put_i18n_message("es", %{
        message_id: "ruleImplementations.props.result_type.percentage",
        definition: "Porcentaje"
      })

      assert %{"data" => data} =
               conn
               |> post(Routes.implementation_upload_path(conn, :create), attrs)
               |> json_response(:ok)

      assert %{"ids" => ids, "errors" => []} = data
      assert length(ids) == 3
    end

    @tag authentication: [role: "admin"]
    test "uploads implementations without rules", %{conn: conn} do
      CacheHelpers.insert_domain(external_id: "some_domain_id")

      attrs = %{
        implementations: %Plug.Upload{
          filename: "implementations_without_rules.csv",
          path: "test/fixtures/implementations/implementations_without_rules.csv"
        }
      }

      assert %{"data" => data} =
               conn
               |> post(Routes.implementation_upload_path(conn, :create), attrs)
               |> json_response(:ok)

      assert %{"ids" => ids, "errors" => []} = data
      assert length(ids) == 3
    end

    @tag authentication: [role: "user"]
    test "user can upload implementations without rules if it has permissions", %{
      conn: conn,
      claims: claims
    } do
      %{id: domain_id} = CacheHelpers.insert_domain(external_id: "some_domain_id")

      attrs = %{
        implementations: %Plug.Upload{
          filename: "implementations_without_rules.csv",
          path: "test/fixtures/implementations/implementations_without_rules.csv"
        }
      }

      CacheHelpers.put_session_permissions(claims, domain_id, [
        :manage_basic_implementations,
        :manage_ruleless_implementations
      ])

      assert %{"data" => data} =
               conn
               |> post(Routes.implementation_upload_path(conn, :create), attrs)
               |> json_response(:ok)

      assert %{"ids" => ids, "errors" => []} = data
      assert length(ids) == 3
    end

    @tag authentication: [role: "user"]
    test "keep published implementations on update without auto_publish", %{
      conn: conn,
      claims: claims
    } do
      %{id: domain_id} = CacheHelpers.insert_domain(external_id: "some_domain_id")

      attrs = %{
        "implementations" => %Plug.Upload{
          filename: "implementations_without_rules.csv",
          path: "test/fixtures/implementations/implementations_without_rules.csv"
        }
      }

      %{id: _implementation_boo_key_2_id} =
        insert(
          :implementation,
          implementation_key: "boo_key_2",
          df_content: %{string: "boo_2"},
          implementation_type: "basic",
          domain_id: domain_id,
          status: :published,
          version: 1,
          minimum: 10,
          goal: 20,
          segments: []
        )

      assert [{_, version, id, :published}] =
               Implementations.list_implementations()
               |> Enum.map(&{&1.implementation_key, &1.version, &1.id, &1.status})

      CacheHelpers.put_session_permissions(claims, domain_id, [
        :manage_basic_implementations,
        :manage_ruleless_implementations
      ])

      assert %{"data" => data} =
               conn
               |> post(Routes.implementation_upload_path(conn, :create), attrs)
               |> json_response(:ok)

      assert [
               {_, ^version, ^id, :published},
               {_, _, _, :draft},
               {_, _, _, :draft},
               {_, _, _, :draft}
             ] =
               Implementations.list_implementations()
               |> Enum.sort(&(&1.status >= &2.status))
               |> Enum.map(&{&1.implementation_key, &1.version, &1.id, &1.status})

      assert %{"ids" => ids, "errors" => []} = data
      assert length(ids) == 3
    end

    @tag authentication: [role: "admin"]
    test "uploads implementations with and without rules", %{conn: conn} do
      CacheHelpers.insert_domain(external_id: "some_domain_id")

      attrs = %{
        implementations: %Plug.Upload{
          filename: "implementations_without_rules.csv",
          path: "test/fixtures/implementations/implementations_with_and_without_rules.csv"
        }
      }

      assert %{"data" => data} =
               conn
               |> post(Routes.implementation_upload_path(conn, :create), attrs)
               |> json_response(:ok)

      assert %{"ids" => ids, "errors" => errors} = data

      assert [
               %{
                 "implementation_key" => "boo_key_7",
                 "message" => %{
                   "domain_external_id" => [
                     "Domain with external id other_domain_id doesn't exist"
                   ]
                 }
               }
             ] == errors

      assert length(ids) == 6
    end

    @tag authentication: [role: "admin"]
    test "renders errors", %{conn: conn} do
      attrs = %{
        implementations: %Plug.Upload{
          filename: "implementations.csv",
          path: "test/fixtures/implementations/implementations_errors.csv"
        }
      }

      assert %{"data" => data} =
               conn
               |> post(Routes.implementation_upload_path(conn, :create), attrs)
               |> json_response(:ok)

      assert %{"errors" => errors, "ids" => []} = data
      assert length(errors) == 4
    end

    @tag authentication: [role: "admin"]
    test "renders error with malformed file", %{conn: conn} do
      attrs = %{
        implementations: %Plug.Upload{
          filename: "implementations.csv",
          path: "test/fixtures/implementations/implementations_malformed.csv"
        }
      }

      assert %{"error" => error} =
               conn
               |> post(Routes.implementation_upload_path(conn, :create), attrs)
               |> json_response(:unprocessable_entity)

      assert error == %{
               "error" => "missing_required_columns",
               "expected" => "implementation_key, result_type, goal, minimum",
               "found" => "with_no_required_headers, foo, bar"
             }
    end
  end
end
