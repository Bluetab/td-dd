defmodule TdDdWeb.StructureNoteControllerTest do
  use TdDdWeb.ConnCase
  use PhoenixSwagger.SchemaTest, "priv/static/swagger.json"

  alias TdCluster.TestHelpers.TdAiMock
  alias TdDd.DataStructures.StructureNote

  import TdDd.TestOperators

  @moduletag sandbox: :shared
  @template_name "structure_note_controller_test_template"

  @identifier_template %{
    id: System.unique_integer([:positive]),
    label: "identifier_test",
    name: "identifier_test",
    scope: "dd",
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

  setup do
    %{id: template_id, name: template_name} = CacheHelpers.insert_template(name: @template_name)
    CacheHelpers.insert_structure_type(name: template_name, template_id: template_id)

    start_supervised!(TdDd.Search.StructureEnricher)

    :ok
  end

  describe "index" do
    @tag authentication: [role: "admin"]
    test "lists all structure_notes", %{conn: conn} do
      %{id: data_structure_id} = insert(:data_structure)

      assert [] ==
               conn
               |> get(Routes.data_structure_note_path(conn, :index, data_structure_id))
               |> json_response(:ok)
               |> Map.get("data")
    end

    @tag authentication: [
           user_name: "non_admin_user",
           permissions: [:view_structure_note_history, :view_data_structure]
         ]
    test "lists all structure_notes if user has the view_structure_note_history permission", %{
      conn: conn,
      domain: domain
    } do
      %{id: data_structure_id} = insert(:data_structure, domain_ids: [domain.id])

      assert [] ==
               conn
               |> get(Routes.data_structure_note_path(conn, :index, data_structure_id))
               |> json_response(:ok)
               |> Map.get("data")
    end

    @tag authentication: [role: "admin"]
    test "actions from a structure with a published note", %{conn: conn} do
      %{id: data_structure_id} = data_structure = insert(:data_structure)
      insert(:structure_note, data_structure: data_structure, status: :published)

      %{
        "data" => [%{"_actions" => sn_actions, "status" => "published"}],
        "_actions" => actions
      } =
        conn
        |> get(Routes.data_structure_note_path(conn, :index, data_structure_id))
        |> json_response(:ok)

      assert ["draft"] ||| Map.keys(actions)
      assert ["deprecated"] == Map.keys(sn_actions)
    end

    @tag authentication: [role: "admin"]
    test "actions from a structure with a published and draft note", %{conn: conn} do
      %{id: data_structure_id} = data_structure = insert(:data_structure)
      insert(:structure_note, data_structure: data_structure, status: :published, version: 1)
      insert(:structure_note, data_structure: data_structure, status: :draft, version: 2)

      %{
        "data" => [
          %{"_actions" => v1_actions, "status" => "published", "version" => 1},
          %{"_actions" => v2_actions, "status" => "draft", "version" => 2}
        ],
        "_actions" => actions
      } =
        conn
        |> get(Routes.data_structure_note_path(conn, :index, data_structure_id))
        |> json_response(:ok)

      assert [] == Map.keys(actions)
      assert [] == Map.keys(v1_actions)

      assert ["deleted", "edited", "pending_approval", "published", "ai_suggestions"] |||
               Map.keys(v2_actions)
    end

    @tag authentication: [role: "admin"]
    test "actions from a structure with a versioned, a published and pending_approval note", %{
      conn: conn
    } do
      %{id: data_structure_id} = data_structure = insert(:data_structure)
      insert(:structure_note, data_structure: data_structure, status: :versioned, version: 1)
      insert(:structure_note, data_structure: data_structure, status: :published, version: 2)

      insert(:structure_note,
        data_structure: data_structure,
        status: :pending_approval,
        version: 3
      )

      %{
        "data" => [
          %{"_actions" => v1_actions, "status" => "versioned", "version" => 1},
          %{"_actions" => v2_actions, "status" => "published", "version" => 2},
          %{"_actions" => v3_actions, "status" => "pending_approval", "version" => 3}
        ],
        "_actions" => actions
      } =
        conn
        |> get(Routes.data_structure_note_path(conn, :index, data_structure_id))
        |> json_response(:ok)

      assert [] == Map.keys(actions)
      assert [] == Map.keys(v1_actions)
      assert [] == Map.keys(v2_actions)
      assert ["rejected", "published"] ||| Map.keys(v3_actions)
    end

    @tag authentication: [role: "admin"]
    test "actions from a structure without notes", %{conn: conn} do
      %{id: data_structure_id} = insert(:data_structure)

      %{
        "data" => [],
        "_actions" => actions
      } =
        conn
        |> get(Routes.data_structure_note_path(conn, :index, data_structure_id))
        |> json_response(:ok)

      assert ["draft"] ||| Map.keys(actions)
    end

    @tag authentication: [role: "admin"]
    test "ai_suggestions action available if there are ai_suggestion fields in template and TdAi.ResourceMapping available",
         %{
           conn: conn
         } do
      template = %{
        id: System.unique_integer([:positive]),
        label: "suggestions_test",
        name: "suggestions_test",
        scope: "dd",
        content: [
          %{
            "name" => "Identifier Template",
            "fields" => [
              %{
                "cardinality" => "1",
                "description" => "field description",
                "label" => "suggestion_field",
                "name" => "suggestion_field",
                "type" => "string",
                "ai_suggestion" => true
              },
              %{
                "cardinality" => "1",
                "label" => "not_suggestion_field",
                "name" => "not_suggestion_field",
                "type" => "string"
              }
            ]
          }
        ]
      }

      TdAiMock.available_resource_mapping(&Mox.expect/4, [], {:ok, true})

      %{id: template_id} = CacheHelpers.insert_template(template)
      CacheHelpers.insert_structure_type(name: template.name, template_id: template_id)

      %{id: data_structure_id} = data_structure = insert(:data_structure)

      insert(:data_structure_version,
        data_structure: data_structure,
        type: template.name
      )

      %{
        "data" => [],
        "_actions" => actions
      } =
        conn
        |> get(Routes.data_structure_note_path(conn, :index, data_structure_id))
        |> json_response(:ok)

      assert actions |> Map.keys() |> Enum.member?("ai_suggestions")
    end

    @tag authentication: [role: "admin"]
    test "ai_suggestions action not available if no ai_suggestion fields in template", %{
      conn: conn
    } do
      %{id: template_id} = template = CacheHelpers.insert_template()
      CacheHelpers.insert_structure_type(name: template.name, template_id: template_id)

      %{id: data_structure_id} = data_structure = insert(:data_structure)

      insert(:data_structure_version,
        data_structure: data_structure,
        type: template.name
      )

      %{
        "data" => [],
        "_actions" => actions
      } =
        conn
        |> get(Routes.data_structure_note_path(conn, :index, data_structure_id))
        |> json_response(:ok)

      refute actions |> Map.keys() |> Enum.member?("ai_suggestions")
    end

    @tag authentication: [role: "admin"]
    test "ai_suggestions action not available if TdAi.ResourceMapping not available", %{
      conn: conn
    } do
      template = %{
        id: System.unique_integer([:positive]),
        label: "suggestions_test",
        name: "suggestions_test",
        scope: "dd",
        content: [
          %{
            "name" => "Identifier Template",
            "fields" => [
              %{
                "cardinality" => "1",
                "description" => "field description",
                "label" => "suggestion_field",
                "name" => "suggestion_field",
                "type" => "string",
                "ai_suggestion" => true
              },
              %{
                "cardinality" => "1",
                "label" => "not_suggestion_field",
                "name" => "not_suggestion_field",
                "type" => "string"
              }
            ]
          }
        ]
      }

      %{id: template_id} = CacheHelpers.insert_template(template)
      CacheHelpers.insert_structure_type(name: template.name, template_id: template_id)

      %{id: data_structure_id} = data_structure = insert(:data_structure)

      insert(:data_structure_version,
        data_structure: data_structure,
        type: template.name
      )

      TdAiMock.available_resource_mapping(&Mox.expect/4, [], {:ok, false})

      %{
        "data" => [],
        "_actions" => actions
      } =
        conn
        |> get(Routes.data_structure_note_path(conn, :index, data_structure_id))
        |> json_response(:ok)

      refute actions |> Map.keys() |> Enum.member?("ai_suggestions")
    end

    @tag authentication: [role: "admin"]
    test "diff from a structure with a published and draft note", %{conn: conn} do
      %{id: data_structure_id} = data_structure = insert(:data_structure)

      insert(
        :structure_note,
        data_structure: data_structure,
        status: :published,
        version: 1,
        df_content: %{
          "foo" => "bar",
          "baz" => "xyz",
          "old" => "value_to_remove"
        }
      )

      insert(
        :structure_note,
        data_structure: data_structure,
        status: :draft,
        version: 2,
        df_content: %{
          "foo" => "bar",
          "baz" => "qux",
          "new" => "value"
        }
      )

      %{
        "data" => [
          %{"status" => "published", "version" => 1},
          %{"_diff" => diff, "status" => "draft", "version" => 2}
        ]
      } =
        conn
        |> get(Routes.data_structure_note_path(conn, :index, data_structure_id))
        |> json_response(:ok)

      assert ["old", "baz", "new"] ||| diff
    end

    @tag authentication: [role: "admin"]
    test "diff from a structure with a published and pending_approval note", %{conn: conn} do
      %{id: data_structure_id} = data_structure = insert(:data_structure)

      insert(
        :structure_note,
        data_structure: data_structure,
        status: :published,
        version: 1,
        df_content: %{
          "foo" => "bar",
          "baz" => "xyz"
        }
      )

      insert(
        :structure_note,
        data_structure: data_structure,
        status: :pending_approval,
        version: 2,
        df_content: %{
          "foo" => "bar",
          "baz" => "qux"
        }
      )

      %{
        "data" => [
          %{"status" => "published", "version" => 1},
          %{"_diff" => diff, "status" => "pending_approval", "version" => 2}
        ]
      } =
        conn
        |> get(Routes.data_structure_note_path(conn, :index, data_structure_id))
        |> json_response(:ok)

      assert ["baz"] == diff
    end

    @tag authentication: [
           user_name: "non_admin_user",
           permissions: [:view_data_structure]
         ]
    test "a user without permission cannot have draft action", %{conn: conn, domain: domain} do
      %{id: data_structure_id} = insert(:data_structure, domain_ids: [domain.id])

      assert %{} ==
               conn
               |> get(Routes.data_structure_note_path(conn, :index, data_structure_id))
               |> json_response(:ok)
               |> Map.get("_actions")
    end

    @tag authentication: [
           user_name: "non_admin_user",
           permissions: [:some_permission]
         ]
    test "can't lists all structure_notes if user hasn't the correct permission", %{
      conn: conn,
      domain: domain
    } do
      %{id: data_structure_id} = insert(:data_structure, domain_ids: [domain.id])

      conn
      |> get(Routes.data_structure_note_path(conn, :index, data_structure_id))
      |> json_response(:forbidden)
    end

    @tag authentication: [role: "admin"]
    test "only list structure notes of its data structure", %{conn: conn, swagger_schema: schema} do
      %{id: first_data_structure_id} = first_data_structure = insert(:data_structure)
      %{id: second_data_structure_id} = second_data_structure = insert(:data_structure)

      first_structure_notes =
        [
          insert(:structure_note,
            data_structure: first_data_structure,
            status: :rejected,
            version: 1
          ),
          insert(:structure_note,
            data_structure: first_data_structure,
            status: :published,
            version: 2
          ),
          insert(:structure_note, data_structure: first_data_structure, status: :draft, version: 3)
        ]
        |> Enum.map(fn sn -> sn.id end)

      second_structure_notes =
        [
          insert(:structure_note,
            data_structure: second_data_structure,
            status: :draft,
            version: 2
          ),
          insert(:structure_note,
            data_structure: second_data_structure,
            status: :rejected,
            version: 1
          )
        ]
        |> Enum.map(fn sn -> sn.id end)

      assert first_structure_notes |||
               conn
               |> get(Routes.data_structure_note_path(conn, :index, first_data_structure_id))
               |> validate_resp_schema(schema, "StructureNotesResponse")
               |> json_response(:ok)
               |> Map.get("data")
               |> Enum.map(fn sn -> Map.get(sn, "id") end)

      assert second_structure_notes |||
               conn
               |> get(Routes.data_structure_note_path(conn, :index, second_data_structure_id))
               |> json_response(:ok)
               |> Map.get("data")
               |> Enum.map(fn sn -> Map.get(sn, "id") end)
    end

    @tag authentication: [
           user_name: "non_admin_user",
           permissions: [:edit_structure_note, :view_data_structure]
         ]
    test "user with edit_structure_note permission can only view structure_notes in draft and published status",
         %{conn: conn, domain: domain} do
      statuses = [
        :rejected,
        :published,
        :draft
      ]

      {[_, published_note, draft_note], index_result} =
        permissions_test_builder(conn, domain, statuses)

      assert [published_note, draft_note] ||| index_result
    end

    @tag authentication: [
           user_name: "non_admin_user",
           permissions: [:publish_structure_note_from_draft, :view_data_structure]
         ]
    test "user with publish_structure_note_from_draft permission can only view structure_notes in draft and published statuses",
         %{conn: conn, domain: domain} do
      statuses = [
        :rejected,
        :published,
        :pending_approval,
        :draft
      ]

      {[_, published_note, _, draft_note], index_result} =
        permissions_test_builder(conn, domain, statuses)

      assert [published_note, draft_note] ||| index_result
    end

    @tag authentication: [
           user_name: "non_admin_user",
           permissions: [:view_structure_note_history, :view_data_structure]
         ]
    test "user with view_structure_note_history permission can only view structure_notes in versioned and published statuses",
         %{conn: conn, domain: domain} do
      statuses = [
        :rejected,
        :published,
        :versioned,
        :pending_approval,
        :draft,
        :deprecated
      ]

      {[_, published_note, versioned_note, _, _, deprecated_note], index_result} =
        permissions_test_builder(conn, domain, statuses)

      assert [published_note, versioned_note, deprecated_note] ||| index_result
    end

    defp permissions_test_builder(conn, domain, statuses) do
      %{id: data_structure_id} = data_structure = insert(:data_structure, domain_ids: [domain.id])

      structure_notes =
        statuses
        |> Enum.with_index()
        |> Enum.map(fn {status, idx} ->
          insert(:structure_note, data_structure: data_structure, status: status, version: idx)
        end)
        |> Enum.map(fn sn -> sn.id end)

      index_result =
        conn
        |> get(Routes.data_structure_note_path(conn, :index, data_structure_id))
        |> json_response(:ok)
        |> Map.get("data")
        |> Enum.map(fn sn -> Map.get(sn, "id") end)

      {structure_notes, index_result}
    end
  end

  describe "search" do
    @tag authentication: [role: "admin"]
    test "search structure_notes by status and updated_at", %{conn: conn} do
      ts = ~U[2021-01-10T11:00:00Z]
      ts2 = ~U[2021-01-01T11:00:00Z]

      n1 = insert(:structure_note, status: :published, updated_at: ts)
      n2 = insert(:structure_note, status: :published, updated_at: ts)
      insert(:structure_note, status: :published, updated_at: ts2)
      insert(:structure_note, status: :draft, updated_at: ts)

      response =
        [n1, n2]
        |> Enum.map(fn sn ->
          %{
            "id" => sn.id,
            "status" => sn.status |> Atom.to_string(),
            "df_content" => sn.df_content,
            "data_structure_id" => sn.data_structure_id,
            "data_structure_external_id" => sn.data_structure.external_id,
            "updated_at" => DateTime.to_iso8601(sn.updated_at),
            "version" => 1
          }
        end)

      assert response |||
               conn
               |> post(Routes.structure_note_path(conn, :search),
                 status: "published",
                 updated_at: "2021-01-02 10:00:00"
               )
               |> json_response(:ok)
               |> Map.get("data")
    end

    @tag authentication: [role: "admin"]
    test "search structure_notes by filter with until param", %{conn: conn} do
      n1 = insert(:structure_note, status: :published, updated_at: ~U[2021-01-01T11:00:00Z])
      n2 = insert(:structure_note, status: :published, updated_at: ~U[2021-01-02T11:00:00Z])
      insert(:structure_note, status: :published, updated_at: ~U[2021-01-03T11:00:00Z])
      insert(:structure_note, status: :draft, updated_at: ~U[2021-01-04T11:00:00Z])

      response =
        [n1, n2]
        |> Enum.map(fn sn ->
          %{
            "id" => sn.id,
            "status" => sn.status |> Atom.to_string(),
            "df_content" => sn.df_content,
            "data_structure_id" => sn.data_structure_id,
            "data_structure_external_id" => sn.data_structure.external_id,
            "updated_at" => DateTime.to_iso8601(sn.updated_at),
            "version" => 1
          }
        end)

      assert response |||
               conn
               |> post(Routes.structure_note_path(conn, :search),
                 until: "2021-01-02 11:00:00"
               )
               |> json_response(:ok)
               |> Map.get("data")
    end

    @tag authentication: [role: "admin"]
    test "search structure_notes by data_struture system_id", %{conn: conn} do
      %{system_id: system_id} = ds1 = insert(:data_structure)
      ds2 = insert(:data_structure)
      %{id: note_id} = insert(:structure_note, data_structure: ds1)
      insert(:structure_note, data_structure: ds2)

      assert [%{"id" => ^note_id}] =
               conn
               |> post(Routes.structure_note_path(conn, :search),
                 system_id: system_id
               )
               |> json_response(:ok)
               |> Map.get("data")
    end

    @tag authentication: [user_name: "no_admin_user"]
    test "only admins can search structure_notes by status and updated_at", %{conn: conn} do
      insert(:structure_note, status: :published, updated_at: "2021-01-10T11:00:00")
      insert(:structure_note, status: :published, updated_at: "2021-01-10T11:00:00")
      insert(:structure_note, status: :published, updated_at: "2021-01-01T11:00:00")
      insert(:structure_note, status: :draft, updated_at: "2021-01-10T11:00:00")

      conn
      |> post(Routes.structure_note_path(conn, :search),
        status: "published",
        updated_at: "2021-01-02 10:00:00"
      )
      |> json_response(:forbidden)
    end
  end

  describe "create structure_note" do
    @tag authentication: [role: "admin"]
    test "renders structure_note when data is valid", %{conn: conn, swagger_schema: schema} do
      %{id: data_structure_id} = insert(:data_structure)
      create_attrs = string_params_for(:structure_note)

      %{"data" => %{"id" => id}} =
        conn
        |> post(Routes.data_structure_note_path(conn, :create, data_structure_id),
          structure_note: create_attrs
        )
        |> validate_resp_schema(schema, "StructureNoteResponse")
        |> json_response(:created)

      assert %{
               "id" => ^id,
               "df_content" => %{},
               "status" => "draft",
               "version" => 1
             } =
               conn
               |> get(Routes.data_structure_note_path(conn, :show, data_structure_id, id))
               |> json_response(:ok)
               |> Map.get("data")
    end

    @tag authentication: [user_name: "non_admin_user"]
    test "non admin user cannot create structure_note", %{conn: conn} do
      %{id: data_structure_id} = insert(:data_structure)
      create_attrs = string_params_for(:structure_note)

      assert conn
             |> post(Routes.data_structure_note_path(conn, :create, data_structure_id),
               structure_note: create_attrs
             )
             |> response(:forbidden)
    end

    @tag authentication: [role: "admin"]
    test "generates identifier field for structure note", %{conn: conn} do
      %{id: template_id, name: template_name} = CacheHelpers.insert_template(@identifier_template)
      CacheHelpers.insert_structure_type(name: template_name, template_id: template_id)

      %{id: data_structure_id} = data_structure = insert(:data_structure)

      insert(:data_structure_version,
        data_structure: data_structure,
        type: template_name
      )

      create_attrs = string_params_for(:structure_note, df_content: %{"identifier_field" => ""})

      %{"data" => %{"id" => id}} =
        conn
        |> post(Routes.data_structure_note_path(conn, :create, data_structure_id),
          structure_note: create_attrs
        )
        |> json_response(:created)

      assert %{
               "id" => ^id,
               "df_content" => %{"identifier_field" => identifier_value}
             } =
               conn
               |> get(Routes.data_structure_note_path(conn, :show, data_structure_id, id))
               |> json_response(:ok)
               |> Map.get("data")

      refute is_nil(identifier_value) or identifier_value == ""
    end

    @tag authentication: [role: "admin"]
    test "renders error when creating note with existing draft", %{conn: conn} do
      %{id: data_structure_id} = insert(:data_structure)
      create_attrs = string_params_for(:structure_note)

      assert conn
             |> post(Routes.data_structure_note_path(conn, :create, data_structure_id),
               structure_note: create_attrs
             )
             |> json_response(:created)

      assert conn
             |> post(Routes.data_structure_note_path(conn, :create, data_structure_id),
               structure_note: create_attrs
             )
             |> json_response(:conflict)
    end

    @tag authentication: [role: "admin"]
    test "renders errors when data is invalid", %{conn: conn} do
      %{id: data_structure_id} = insert(:data_structure)

      assert %{"df_content" => ["can't be blank"]} =
               conn
               |> post(Routes.data_structure_note_path(conn, :create, data_structure_id),
                 structure_note: %{}
               )
               |> json_response(:unprocessable_entity)
               |> Map.get("errors")
    end
  end

  describe "update structure_note" do
    @tag authentication: [role: "admin"]
    test "renders structure_note when data is valid", %{conn: conn, swagger_schema: schema} do
      data_structure = insert(:data_structure)

      %StructureNote{id: id} =
        structure_note = insert(:structure_note, data_structure: data_structure)

      insert(:data_structure_version,
        data_structure: data_structure,
        type: @template_name
      )

      update_attrs = %{df_content: %{"string" => "value", "list" => "two"}}

      assert %{"id" => ^id} =
               conn
               |> put(
                 Routes.data_structure_note_path(
                   conn,
                   :update,
                   data_structure.id,
                   structure_note
                 ),
                 structure_note: update_attrs
               )
               |> validate_resp_schema(schema, "StructureNoteResponse")
               |> json_response(:ok)
               |> Map.get("data")

      assert %{
               "id" => ^id,
               "df_content" => %{"string" => "value", "list" => "two"},
               "status" => "draft"
             } =
               conn
               |> get(Routes.data_structure_note_path(conn, :show, data_structure.id, id))
               |> json_response(:ok)
               |> Map.get("data")
    end

    @tag authentication: [role: "admin"]
    test "renders errors when data is invalid", %{conn: conn} do
      structure_note = insert(:structure_note)

      assert %{"errors" => errors} =
               conn
               |> put(
                 Routes.data_structure_note_path(
                   conn,
                   :update,
                   structure_note.data_structure.id,
                   structure_note
                 ),
                 structure_note: %{df_content: nil}
               )
               |> json_response(:unprocessable_entity)

      assert %{
               "df_content" => ["can't be blank"]
             } = errors
    end

    @tag authentication: [user_name: "non_admin_user"]
    test "non admin user can not publish a draft note", %{conn: conn} do
      %StructureNote{
        data_structure_id: data_structure_id
      } = structure_note = insert(:structure_note)

      update_attrs =
        string_params_for(:structure_note, status: "published", df_content: %{"foo" => "bar"})

      conn
      |> put(
        Routes.data_structure_note_path(conn, :update, data_structure_id, structure_note),
        structure_note: update_attrs
      )
      |> json_response(:forbidden)
    end

    @tag authentication: [role: "admin"]
    test "can publish a draft note when the user has the right permissions", %{conn: conn} do
      %StructureNote{
        data_structure_id: data_structure_id
      } = structure_note = insert(:structure_note)

      update_attrs = %{"status" => "published"}

      conn
      |> put(
        Routes.data_structure_note_path(conn, :update, data_structure_id, structure_note),
        structure_note: update_attrs
      )
      |> json_response(:ok)
    end
  end

  describe "delete structure_note" do
    @tag authentication: [
           user_name: "non_admin_user",
           permissions: [:delete_structure_note, :view_data_structure]
         ]
    test "deletes chosen structure_note", %{conn: conn, domain: domain} do
      %{id: data_structure_id} = insert(:data_structure, domain_ids: [domain.id])
      structure_note = insert(:structure_note, data_structure_id: data_structure_id)

      assert conn
             |> delete(
               Routes.data_structure_note_path(conn, :delete, data_structure_id, structure_note)
             )
             |> response(:no_content)

      assert_error_sent(:not_found, fn ->
        get(conn, Routes.data_structure_note_path(conn, :show, data_structure_id, structure_note))
      end)
    end

    @tag authentication: [
           user_name: "non_admin_user",
           permissions: [:create_structure_note, :view_data_structure]
         ]
    test "cannot delete structure_note without permission", %{conn: conn, domain: domain} do
      %{id: data_structure_id} = insert(:data_structure, domain_ids: [domain.id])
      structure_note = insert(:structure_note, data_structure_id: data_structure_id)

      assert conn
             |> delete(
               Routes.data_structure_note_path(conn, :delete, data_structure_id, structure_note)
             )
             |> response(:forbidden)
    end
  end

  describe "note_suggestions" do
    @tag authentication: [role: "admin"]
    test "retrieves suggestions for the requested fields", %{conn: conn} do
      template = %{
        id: System.unique_integer([:positive]),
        label: "suggestions_test",
        name: "suggestions_test",
        scope: "dd",
        content: [
          %{
            "name" => "Identifier Template",
            "fields" => [
              %{
                "cardinality" => "1",
                "label" => "suggestion_field",
                "name" => "suggestion_field",
                "type" => "string",
                "ai_suggestion" => true
              },
              %{
                "cardinality" => "1",
                "label" => "not_suggestion_field",
                "name" => "not_suggestion_field",
                "type" => "string"
              }
            ]
          }
        ]
      }

      %{id: template_id, name: template_name} = CacheHelpers.insert_template(template)
      CacheHelpers.insert_structure_type(name: template_name, template_id: template_id)

      %{id: data_structure_id} = data_structure = insert(:data_structure)

      insert(:data_structure_version,
        data_structure: data_structure,
        type: template_name
      )

      args = {"data_structure", data_structure_id, %{name: "field"}}

      TdAiMock.resource_field_completion(&Mox.expect/4, args, {:ok, %{}})

      assert %{} ==
               conn
               |> get(
                 Routes.data_structure_structure_note_path(
                   conn,
                   :note_suggestions,
                   data_structure_id
                 )
               )
               |> json_response(:ok)
               |> Map.get("data")
    end
  end

  describe "permissions over structure_notes" do
    @tag authentication: [user_name: "non_admin_user"]
    test "can't create notes", %{conn: conn} do
      %{id: data_structure_id} = insert(:data_structure)
      create_attrs = string_params_for(:structure_note)

      conn
      |> post(Routes.data_structure_note_path(conn, :create, data_structure_id),
        structure_note: create_attrs
      )
      |> json_response(:forbidden)
    end

    @tag authentication: [
           user_name: "non_admin_user",
           permissions: [:create_structure_note, :view_data_structure]
         ]
    test "can create notes", %{conn: conn, domain: domain} do
      %{id: data_structure_id} = insert(:data_structure, domain_ids: [domain.id])
      create_attrs = string_params_for(:structure_note)

      conn
      |> post(Routes.data_structure_note_path(conn, :create, data_structure_id),
        structure_note: create_attrs
      )
      |> json_response(:created)
    end

    @tag authentication: [role: "admin"]
    test "only admins can create a note with force", %{conn: conn} do
      %{id: data_structure_id} = insert(:data_structure)
      create_attrs = string_params_for(:structure_note)

      %{"data" => %{"id" => id}} =
        conn
        |> post(Routes.data_structure_note_path(conn, :create, data_structure_id),
          structure_note: create_attrs
        )
        |> json_response(:created)

      conn
      |> put(Routes.data_structure_note_path(conn, :update, data_structure_id, id),
        structure_note: %{"status" => "pending_approval"}
      )
      |> json_response(:ok)

      %{"data" => %{"id" => new_id, "version" => version}} =
        conn
        |> post(Routes.data_structure_note_path(conn, :create, data_structure_id),
          structure_note: create_attrs,
          force: true
        )
        |> json_response(:created)

      assert new_id != id
      assert version == 1
    end

    @tag authentication: [role: "admin"]
    test "admins can create a note with force by external id", %{conn: conn} do
      %{id: data_structure_id, external_id: data_structure_external_id} = insert(:data_structure)
      create_attrs = string_params_for(:structure_note)

      %{"data" => %{"id" => id}} =
        conn
        |> post(Routes.data_structure_note_path(conn, :create, data_structure_id),
          structure_note: create_attrs
        )
        |> json_response(:created)

      conn
      |> put(Routes.data_structure_note_path(conn, :update, data_structure_id, id),
        structure_note: %{"status" => "pending_approval"}
      )
      |> json_response(:ok)

      force_create_attrs =
        create_attrs
        |> Map.put("data_structure_external_id", data_structure_external_id)

      %{"data" => %{"id" => new_id, "version" => version}} =
        conn
        |> post(Routes.structure_note_path(conn, :create_by_external_id),
          structure_note: force_create_attrs
        )
        |> json_response(:created)

      assert new_id != id
      assert version == 1
    end

    @tag authentication: [
           user_name: "non_admin_user",
           permissions: [
             :create_structure_note,
             :edit_structure_note,
             :send_structure_note_to_approval,
             :publish_structure_note_from_draft,
             :deprecate_structure_note,
             :view_data_structure
           ]
         ]
    test "common users with a lot of permissions can't create a note with force", %{
      conn: conn,
      domain: domain
    } do
      %{id: data_structure_id} = insert(:data_structure, domain_ids: [domain.id])
      create_attrs = string_params_for(:structure_note)

      %{"data" => %{"id" => id}} =
        conn
        |> post(Routes.data_structure_note_path(conn, :create, data_structure_id),
          structure_note: create_attrs
        )
        |> json_response(:created)

      conn
      |> put(Routes.data_structure_note_path(conn, :update, data_structure_id, id),
        structure_note: %{"status" => "pending_approval"}
      )
      |> json_response(:ok)

      conn
      |> post(Routes.data_structure_note_path(conn, :create, data_structure_id),
        structure_note: create_attrs,
        force: true
      )
      |> json_response(:forbidden)
    end

    @tag authentication: [
           user_name: "non_admin_user",
           permissions: [
             :create_structure_note,
             :edit_structure_note,
             :publish_structure_note_from_draft,
             :deprecate_structure_note,
             :view_data_structure
           ]
         ]
    test "can create notes when the latest note is deprecated, and show the action",
         %{conn: conn, domain: domain} do
      %{id: data_structure_id} = insert(:data_structure, domain_ids: [domain.id])
      create_attrs = string_params_for(:structure_note)

      %{"data" => %{"id" => id}} =
        conn
        |> post(Routes.data_structure_note_path(conn, :create, data_structure_id),
          structure_note: create_attrs
        )
        |> json_response(:created)

      conn
      |> put(Routes.data_structure_note_path(conn, :update, data_structure_id, id),
        structure_note: %{"status" => "published"}
      )
      |> json_response(:ok)

      conn
      |> put(Routes.data_structure_note_path(conn, :update, data_structure_id, id),
        structure_note: %{"status" => "deprecated"}
      )
      |> json_response(:ok)

      %{"_actions" => actions} =
        conn
        |> get(Routes.data_structure_note_path(conn, :index, data_structure_id))
        |> json_response(:ok)

      assert %{"draft" => %{"method" => "POST"}} = actions

      %{"data" => %{"id" => new_id}} =
        conn
        |> post(Routes.data_structure_note_path(conn, :create, data_structure_id),
          structure_note: create_attrs
        )
        |> json_response(:created)

      assert new_id != id
    end

    @tag authentication: [
           user_name: "non_admin_user",
           permissions: [:view_structure_note, :view_data_structure]
         ]
    test "can not create notes", %{conn: conn, domain: domain} do
      %{id: data_structure_id} = insert(:data_structure, domain_ids: [domain.id])
      create_attrs = string_params_for(:structure_note)

      conn
      |> post(Routes.data_structure_note_path(conn, :create, data_structure_id),
        structure_note: create_attrs
      )
      |> json_response(:forbidden)
    end

    @tag authentication: [
           user_name: "non_admin_user",
           permissions: [:create_structure_note, :edit_structure_note, :view_data_structure]
         ]
    test "can edit note after creation", %{conn: conn, domain: domain} do
      %{id: data_structure_id} = insert(:data_structure, domain_ids: [domain.id])
      create_attrs = string_params_for(:structure_note)

      body =
        conn
        |> post(Routes.data_structure_note_path(conn, :create, data_structure_id),
          structure_note: create_attrs
        )
        |> json_response(:created)

      assert "edited" in (body |> Map.get("_actions") |> Map.keys())
    end

    @tag authentication: [
           user_name: "non_admin_user",
           permissions: [:create_structure_note, :view_data_structure]
         ]
    test "can not edit or publish note after creation", %{conn: conn, domain: domain} do
      %{id: data_structure_id} = insert(:data_structure, domain_ids: [domain.id])
      create_attrs = string_params_for(:structure_note)

      body =
        conn
        |> post(Routes.data_structure_note_path(conn, :create, data_structure_id),
          structure_note: create_attrs
        )
        |> json_response(:created)

      assert "edited" not in (body |> Map.get("_actions") |> Map.keys())
      assert "published" not in (body |> Map.get("_actions") |> Map.keys())
    end

    @tag authentication: [
           user_name: "non_admin_user",
           permissions: [
             :create_structure_note,
             :publish_structure_note_from_draft,
             :view_data_structure
           ]
         ]
    test "can not publish note after creation", %{conn: conn, domain: domain} do
      %{id: data_structure_id} = insert(:data_structure, domain_ids: [domain.id])
      create_attrs = string_params_for(:structure_note)

      body =
        conn
        |> post(Routes.data_structure_note_path(conn, :create, data_structure_id),
          structure_note: create_attrs
        )
        |> json_response(:created)

      assert "published" in (body |> Map.get("_actions") |> Map.keys())
    end

    @tag authentication: [
           user_name: "non_admin_user",
           permissions: [
             :create_structure_note,
             :reject_structure_note,
             :send_structure_note_to_approval,
             :view_data_structure
           ]
         ]
    test "can reject a note after send to approval but not after creation", %{
      conn: conn,
      domain: domain
    } do
      %{id: data_structure_id} = insert(:data_structure, domain_ids: [domain.id])
      create_attrs = string_params_for(:structure_note)

      %{"data" => %{"id" => id}} =
        creation_body =
        conn
        |> post(Routes.data_structure_note_path(conn, :create, data_structure_id),
          structure_note: create_attrs
        )
        |> json_response(:created)

      pending_approval_body =
        conn
        |> put(Routes.data_structure_note_path(conn, :update, data_structure_id, id),
          structure_note: %{"status" => "pending_approval"}
        )
        |> json_response(:ok)

      assert "rejected" not in (creation_body |> Map.get("_actions") |> Map.keys())
      assert "rejected" in (pending_approval_body |> Map.get("_actions") |> Map.keys())
    end

    @tag authentication: [
           user_name: "non_admin_user",
           permissions: [
             :create_structure_note,
             :publish_structure_note_from_draft,
             :view_data_structure
           ]
         ]
    test "cannot delete a note after creation", %{conn: conn, domain: domain} do
      %{id: data_structure_id} = insert(:data_structure, domain_ids: [domain.id])
      create_attrs = string_params_for(:structure_note)

      body =
        conn
        |> post(Routes.data_structure_note_path(conn, :create, data_structure_id),
          structure_note: create_attrs
        )
        |> json_response(:created)

      assert "deleted" not in (body |> Map.get("_actions") |> Map.keys())
    end
  end
end
