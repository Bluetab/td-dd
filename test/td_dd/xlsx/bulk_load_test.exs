defmodule TdDd.XLSX.BulkLoadTest do
  use TdDd.DataCase

  import Mox

  alias TdCluster.TestHelpers.TdAuditMock.UploadJobs
  alias TdCore.Search.IndexWorkerMock
  alias TdCore.XLSX.BulkLoad, as: XLSXBulkLoad
  alias TdDd.DataStructures.StructureNote
  alias TdDd.XLSX.BulkLoad
  alias TdDfLib.Format

  @moduletag sandbox: :shared

  setup :verify_on_exit!

  setup do
    start_supervised!(TdDd.Search.StructureEnricher)

    stub(MockClusterHandler, :call, fn :ai,
                                       TdAi.Indices,
                                       :exists_enabled?,
                                       [[index_type: "suggestions"]] ->
      {:ok, true}
    end)

    content = [
      %{
        "name" => "group",
        "fields" => [
          %{
            "cardinality" => "?",
            "label" => "field",
            "name" => "field",
            "type" => "string"
          },
          %{
            "cardinality" => "?",
            "label" => "another_field",
            "name" => "another_field",
            "type" => "string"
          }
        ]
      }
    ]

    %{id: template_id, name: template_name} =
      template =
      CacheHelpers.insert_template(scope: "dd", content: content)

    data_structure_type =
      CacheHelpers.insert_structure_type(name: template_name, template_id: template_id)

    [data_structure_type: data_structure_type, template: template]
  end

  describe "upsert_structure_note/2" do
    test "creates new structure note when no note exists", %{template: template} do
      claims = build(:claims, role: "admin")
      data_structure = insert(:data_structure)
      insert(:data_structure_version, data_structure: data_structure, type: template.name)

      params = %{
        "external_id" => data_structure.external_id,
        "df_content" => %{"field" => %{"value" => "test", "origin" => "file"}},
        "_sheet" => template.name
      }

      ctx = %{
        claims: claims,
        lang: "en",
        to_status: "draft",
        opts: [],
        templates: %{
          template.name => %{content_schema: Format.flatten_content_fields(template.content)}
        }
      }

      assert {:created, {id, details}} = BulkLoad.upsert_structure_note(params, ctx)
      assert details.external_id == data_structure.external_id

      assert [note] =
               StructureNote
               |> where(data_structure_id: ^data_structure.id)
               |> Repo.all()

      assert note.id == id
      assert note.status == :draft
      assert note.version == 1
      assert note.data_structure_id == data_structure.id
      assert note.df_content == %{"field" => %{"value" => "test", "origin" => "file"}}
    end

    test "updates existing draft note", %{template: template} do
      claims = build(:claims, role: "admin")
      data_structure = insert(:data_structure)
      insert(:data_structure_version, data_structure: data_structure, type: template.name)

      existing_note =
        insert(:structure_note,
          data_structure: data_structure,
          status: :draft,
          version: 1,
          df_content: %{"field" => %{"value" => "old_value", "origin" => "user"}}
        )

      params = %{
        "external_id" => data_structure.external_id,
        "df_content" => %{"field" => %{"value" => "new_value", "origin" => "file"}},
        "_sheet" => template.name
      }

      ctx = %{
        claims: claims,
        lang: "en",
        to_status: "draft",
        opts: [],
        templates: %{
          template.name => %{content_schema: Format.flatten_content_fields(template.content)}
        }
      }

      assert {:updated, {id, details}} = BulkLoad.upsert_structure_note(params, ctx)
      assert details.external_id == data_structure.external_id

      assert [note] =
               StructureNote
               |> where(data_structure_id: ^data_structure.id)
               |> Repo.all()

      assert note.id == id
      assert note.id != existing_note.id
      assert note.status == :draft
      assert note.version == 1
      assert note.data_structure_id == data_structure.id
      assert note.df_content == %{"field" => %{"value" => "new_value", "origin" => "file"}}
    end

    test "creates new version when published note exists", %{template: template} do
      claims = build(:claims, role: "admin")
      data_structure = insert(:data_structure)
      insert(:data_structure_version, data_structure: data_structure, type: template.name)

      insert(:structure_note,
        data_structure: data_structure,
        status: :published,
        version: 1
      )

      params = %{
        "external_id" => data_structure.external_id,
        "df_content" => %{"field" => %{"value" => "test", "origin" => "file"}},
        "_sheet" => template.name
      }

      ctx = %{
        claims: claims,
        lang: "en",
        to_status: "draft",
        opts: [],
        templates: %{
          template.name => %{content_schema: Format.flatten_content_fields(template.content)}
        }
      }

      assert {:created, {id, _details}} = BulkLoad.upsert_structure_note(params, ctx)

      assert [published_note, draft_note] =
               StructureNote
               |> where(data_structure_id: ^data_structure.id)
               |> Repo.all()
               |> Enum.sort_by(& &1.version)

      assert published_note.status == :published
      assert published_note.version == 1
      assert draft_note.id == id
      assert draft_note.status == :draft
      assert draft_note.version == 2
    end

    test "creates new version when deprecated note exists", %{template: template} do
      claims = build(:claims, role: "admin")
      data_structure = insert(:data_structure)
      insert(:data_structure_version, data_structure: data_structure, type: template.name)

      insert(:structure_note,
        data_structure: data_structure,
        status: :deprecated,
        version: 1
      )

      params = %{
        "external_id" => data_structure.external_id,
        "df_content" => %{"field" => %{"value" => "test", "origin" => "file"}},
        "_sheet" => template.name
      }

      ctx = %{
        claims: claims,
        lang: "en",
        to_status: "draft",
        opts: [],
        templates: %{
          template.name => %{content_schema: Format.flatten_content_fields(template.content)}
        }
      }

      assert {:created, {id, _details}} = BulkLoad.upsert_structure_note(params, ctx)

      assert [deprecated_note, draft_note] =
               StructureNote
               |> where(data_structure_id: ^data_structure.id)
               |> Repo.all()
               |> Enum.sort_by(& &1.version)

      assert deprecated_note.status == :deprecated
      assert deprecated_note.version == 1
      assert draft_note.id == id
      assert draft_note.status == :draft
      assert draft_note.version == 2
    end

    test "unrejects and updates rejected note", %{template: template} do
      claims = build(:claims, role: "admin")
      data_structure = insert(:data_structure)
      insert(:data_structure_version, data_structure: data_structure, type: template.name)

      rejected_note =
        insert(:structure_note,
          data_structure: data_structure,
          status: :rejected,
          version: 1
        )

      params = %{
        "external_id" => data_structure.external_id,
        "df_content" => %{"field" => %{"value" => "test", "origin" => "file"}},
        "_sheet" => template.name
      }

      ctx = %{
        claims: claims,
        lang: "en",
        to_status: "draft",
        opts: [],
        templates: %{
          template.name => %{content_schema: Format.flatten_content_fields(template.content)}
        }
      }

      assert {:updated, {id, _details}} = BulkLoad.upsert_structure_note(params, ctx)

      assert [note] =
               StructureNote
               |> where(data_structure_id: ^data_structure.id)
               |> Repo.all()

      assert note.id == id
      assert note.id != rejected_note.id
      assert note.status == :draft
      assert note.version == 1
    end

    test "returns error when pending_approval note exists", %{template: template} do
      claims = build(:claims, role: "admin")
      data_structure = insert(:data_structure)
      insert(:data_structure_version, data_structure: data_structure, type: template.name)

      insert(:structure_note,
        data_structure: data_structure,
        status: :pending_approval,
        version: 1
      )

      params = %{
        "external_id" => data_structure.external_id,
        "df_content" => %{"field" => %{"value" => "test", "origin" => "file"}},
        "_sheet" => template.name
      }

      ctx = %{
        claims: claims,
        lang: "en",
        to_status: "draft",
        opts: [],
        templates: %{
          template.name => %{content_schema: Format.flatten_content_fields(template.content)}
        }
      }

      assert {:error, {"pending_approval_conflict", _details}} =
               BulkLoad.upsert_structure_note(params, ctx)

      assert [pending_note] =
               StructureNote
               |> where(data_structure_id: ^data_structure.id)
               |> Repo.all()

      assert pending_note.status == :pending_approval
      assert pending_note.version == 1
    end

    test "returns error when data structure does not exist" do
      claims = build(:claims, role: "admin")

      params = %{
        "external_id" => "non_existent_id",
        "df_content" => %{"field" => %{"value" => "test", "origin" => "file"}},
        "_sheet" => "sheet"
      }

      ctx = %{
        claims: claims,
        lang: "en",
        to_status: "draft",
        opts: [],
        templates: %{}
      }

      assert {:error, {"data_structure_not_found", %{external_id: "non_existent_id"}}} =
               BulkLoad.upsert_structure_note(params, ctx)

      assert [] = Repo.all(StructureNote)
    end

    test "returns error when user lacks manage_structure_note permission", %{
      template: template
    } do
      claims = build(:claims, role: "user")
      data_structure = insert(:data_structure)
      insert(:data_structure_version, data_structure: data_structure, type: template.name)

      params = %{
        "external_id" => data_structure.external_id,
        "df_content" => %{"field" => %{"value" => "test", "origin" => "file"}},
        "_sheet" => template.name
      }

      ctx = %{
        claims: claims,
        lang: "en",
        to_status: "draft",
        opts: [],
        templates: %{
          template.name => %{content_schema: Format.flatten_content_fields(template.content)}
        }
      }

      assert {:error, {"unauthorized", %{external_id: external_id}}} =
               BulkLoad.upsert_structure_note(params, ctx)

      assert external_id == data_structure.external_id
      assert [] = Repo.all(StructureNote)
    end

    test "returns error when user cannot publish and cannot create draft", %{
      template: template
    } do
      claims = build(:claims, role: "user")
      data_structure = insert(:data_structure)
      insert(:data_structure_version, data_structure: data_structure, type: template.name)

      params = %{
        "external_id" => data_structure.external_id,
        "df_content" => %{"field" => %{"value" => "test", "origin" => "file"}},
        "_sheet" => template.name
      }

      ctx = %{
        claims: claims,
        lang: "en",
        to_status: "published",
        opts: [],
        templates: %{
          template.name => %{content_schema: Format.flatten_content_fields(template.content)}
        }
      }

      assert {:error, {"unauthorized", %{external_id: external_id}}} =
               BulkLoad.upsert_structure_note(params, ctx)

      assert external_id == data_structure.external_id
      assert [] = Repo.all(StructureNote)
    end

    test "creates draft when user cannot publish but can create draft", %{
      template: template
    } do
      claims = build(:claims, role: "user")
      domain = CacheHelpers.insert_domain()
      data_structure = insert(:data_structure, domain_ids: [domain.id])
      insert(:data_structure_version, data_structure: data_structure, type: template.name)

      CacheHelpers.put_session_permissions(
        claims,
        domain.id,
        [:create_structure_note, :view_data_structure]
      )

      params = %{
        "external_id" => data_structure.external_id,
        "df_content" => %{"field" => %{"value" => "test", "origin" => "file"}},
        "_sheet" => template.name
      }

      ctx = %{
        claims: claims,
        lang: "en",
        to_status: "published",
        opts: [],
        templates: %{
          template.name => %{content_schema: Format.flatten_content_fields(template.content)}
        }
      }

      assert {:created, {id, _details}} = BulkLoad.upsert_structure_note(params, ctx)

      assert [note] =
               StructureNote
               |> where(data_structure_id: ^data_structure.id)
               |> Repo.all()

      assert note.id == id
      assert note.status == :draft
    end

    test "creates published note when user has publish permission", %{
      template: template
    } do
      claims = build(:claims, role: "user")
      domain = CacheHelpers.insert_domain()
      data_structure = insert(:data_structure, domain_ids: [domain.id])
      insert(:data_structure_version, data_structure: data_structure, type: template.name)

      CacheHelpers.put_session_permissions(
        claims,
        domain.id,
        [:publish_structure_note_from_draft, :view_data_structure]
      )

      params = %{
        "external_id" => data_structure.external_id,
        "df_content" => %{"field" => %{"value" => "test", "origin" => "file"}},
        "_sheet" => template.name
      }

      ctx = %{
        claims: claims,
        lang: "en",
        to_status: "published",
        opts: [],
        templates: %{
          template.name => %{content_schema: Format.flatten_content_fields(template.content)}
        }
      }

      assert {:created, {id, _details}} = BulkLoad.upsert_structure_note(params, ctx)

      assert [note] =
               StructureNote
               |> where(data_structure_id: ^data_structure.id)
               |> Repo.all()

      assert note.id == id
      assert note.status == :published
    end

    test "verifies database state after successful unreject and update", %{
      template: template
    } do
      claims = build(:claims, role: "admin")
      data_structure = insert(:data_structure)
      insert(:data_structure_version, data_structure: data_structure, type: template.name)

      rejected_note =
        insert(:structure_note,
          data_structure: data_structure,
          status: :rejected,
          version: 1,
          df_content: %{"field" => %{"value" => "old_value", "origin" => "user"}}
        )

      params = %{
        "external_id" => data_structure.external_id,
        "df_content" => %{"field" => %{"value" => "new_value", "origin" => "file"}},
        "_sheet" => template.name
      }

      ctx = %{
        claims: claims,
        lang: "en",
        to_status: "draft",
        opts: [],
        templates: %{
          template.name => %{content_schema: Format.flatten_content_fields(template.content)}
        }
      }

      assert {:updated, {id, _details}} = BulkLoad.upsert_structure_note(params, ctx)

      assert [note] =
               StructureNote
               |> where(data_structure_id: ^data_structure.id)
               |> Repo.all()

      assert note.id == id
      assert note.id != rejected_note.id
      assert note.status == :draft
      assert note.version == 1
      assert note.df_content == %{"field" => %{"value" => "new_value", "origin" => "file"}}
    end

    test "returns unchanged when no note exists and content is empty", %{
      template: template
    } do
      claims = build(:claims, role: "admin")
      data_structure = insert(:data_structure)
      insert(:data_structure_version, data_structure: data_structure, type: template.name)

      params = %{
        "external_id" => data_structure.external_id,
        "df_content" => %{},
        "_sheet" => template.name
      }

      ctx = %{
        claims: claims,
        lang: "en",
        to_status: "draft",
        opts: [],
        templates: %{
          template.name => %{content_schema: Format.flatten_content_fields(template.content)}
        }
      }

      assert {:unchanged, details} = BulkLoad.upsert_structure_note(params, ctx)
      assert details.external_id == data_structure.external_id

      assert [] = Repo.all(StructureNote)
    end

    test "returns unchanged when existing note has empty content and new content is empty", %{
      template: template
    } do
      claims = build(:claims, role: "admin")
      data_structure = insert(:data_structure)
      insert(:data_structure_version, data_structure: data_structure, type: template.name)

      existing_note =
        insert(:structure_note,
          data_structure: data_structure,
          status: :draft,
          version: 1,
          df_content: %{}
        )

      params = %{
        "external_id" => data_structure.external_id,
        "df_content" => %{},
        "_sheet" => template.name
      }

      ctx = %{
        claims: claims,
        lang: "en",
        to_status: "draft",
        opts: [],
        templates: %{
          template.name => %{content_schema: Format.flatten_content_fields(template.content)}
        }
      }

      assert {:unchanged, details} = BulkLoad.upsert_structure_note(params, ctx)
      assert details.external_id == data_structure.external_id

      assert [note] =
               StructureNote
               |> where(data_structure_id: ^data_structure.id)
               |> Repo.all()

      assert note.id == existing_note.id
      assert note.df_content == %{}
    end

    test "maintains existing content when new content is completely empty", %{
      template: template
    } do
      claims = build(:claims, role: "admin")
      data_structure = insert(:data_structure)
      insert(:data_structure_version, data_structure: data_structure, type: template.name)

      existing_note =
        insert(:structure_note,
          data_structure: data_structure,
          status: :draft,
          version: 1,
          df_content: %{"field" => %{"value" => "existing_value", "origin" => "user"}}
        )

      params = %{
        "external_id" => data_structure.external_id,
        "df_content" => %{},
        "_sheet" => template.name
      }

      ctx = %{
        claims: claims,
        lang: "en",
        to_status: "draft",
        opts: [],
        templates: %{
          template.name => %{content_schema: Format.flatten_content_fields(template.content)}
        }
      }

      assert {:unchanged, details} = BulkLoad.upsert_structure_note(params, ctx)
      assert details.external_id == data_structure.external_id

      assert [note] =
               StructureNote
               |> where(data_structure_id: ^data_structure.id)
               |> Repo.all()

      assert note.id == existing_note.id
      assert note.df_content == %{"field" => %{"value" => "existing_value", "origin" => "user"}}
    end

    test "deletes field when explicitly sent with empty value", %{template: template} do
      claims = build(:claims, role: "admin")
      data_structure = insert(:data_structure)
      insert(:data_structure_version, data_structure: data_structure, type: template.name)

      existing_note =
        insert(:structure_note,
          data_structure: data_structure,
          status: :draft,
          version: 1,
          df_content: %{
            "field" => %{"value" => "existing_value", "origin" => "user"},
            "another_field" => %{"value" => "keep_this", "origin" => "user"}
          }
        )

      params = %{
        "external_id" => data_structure.external_id,
        "df_content" => %{"field" => %{"value" => "", "origin" => "file"}},
        "_sheet" => template.name
      }

      ctx = %{
        claims: claims,
        lang: "en",
        to_status: "draft",
        opts: [],
        templates: %{
          template.name => %{content_schema: Format.flatten_content_fields(template.content)}
        }
      }

      assert {:updated, {id, details}} = BulkLoad.upsert_structure_note(params, ctx)
      assert details.external_id == data_structure.external_id

      assert [note] =
               StructureNote
               |> where(data_structure_id: ^data_structure.id)
               |> Repo.all()

      assert note.id == id
      assert note.id != existing_note.id

      assert note.df_content == %{
               "another_field" => %{"value" => "keep_this", "origin" => "user"}
             }

      refute Map.has_key?(note.df_content, "field")
    end

    test "returns unchanged when draft content is identical", %{template: template} do
      claims = build(:claims, role: "admin")
      data_structure = insert(:data_structure)
      insert(:data_structure_version, data_structure: data_structure, type: template.name)

      existing_note =
        insert(:structure_note,
          data_structure: data_structure,
          status: :draft,
          version: 1,
          df_content: %{"field" => %{"value" => "test", "origin" => "user"}}
        )

      params = %{
        "external_id" => data_structure.external_id,
        "df_content" => %{"field" => %{"value" => "test", "origin" => "file"}},
        "_sheet" => template.name
      }

      ctx = %{
        claims: claims,
        lang: "en",
        to_status: "draft",
        opts: [],
        templates: %{
          template.name => %{content_schema: Format.flatten_content_fields(template.content)}
        }
      }

      assert {:unchanged, details} = BulkLoad.upsert_structure_note(params, ctx)
      assert details.external_id == data_structure.external_id

      assert [note] =
               StructureNote
               |> where(data_structure_id: ^data_structure.id)
               |> Repo.all()

      assert note.id == existing_note.id
      assert note.df_content == %{"field" => %{"value" => "test", "origin" => "user"}}
    end

    test "returns unchanged when published content is identical", %{template: template} do
      claims = build(:claims, role: "admin")
      data_structure = insert(:data_structure)
      insert(:data_structure_version, data_structure: data_structure, type: template.name)

      existing_note =
        insert(:structure_note,
          data_structure: data_structure,
          status: :published,
          version: 1,
          df_content: %{"field" => %{"value" => "test", "origin" => "user"}}
        )

      params = %{
        "external_id" => data_structure.external_id,
        "df_content" => %{"field" => %{"value" => "test", "origin" => "file"}},
        "_sheet" => template.name
      }

      ctx = %{
        claims: claims,
        lang: "en",
        to_status: "published",
        opts: [],
        templates: %{
          template.name => %{content_schema: Format.flatten_content_fields(template.content)}
        }
      }

      assert {:unchanged, details} = BulkLoad.upsert_structure_note(params, ctx)
      assert details.external_id == data_structure.external_id

      assert [note] =
               StructureNote
               |> where(data_structure_id: ^data_structure.id)
               |> Repo.all()

      assert note.id == existing_note.id
      assert note.status == :published
    end

    test "returns error when template does not exist" do
      claims = build(:claims, role: "admin")
      data_structure = insert(:data_structure)

      insert(:data_structure_version,
        data_structure: data_structure,
        type: "non_existent_template"
      )

      params = %{
        "external_id" => data_structure.external_id,
        "df_content" => %{"field" => %{"value" => "test", "origin" => "file"}},
        "_sheet" => "non_existent_template"
      }

      ctx = %{
        claims: claims,
        lang: "en",
        to_status: "draft",
        opts: [],
        templates: %{}
      }

      assert {:error, {"template_not_found", %{external_id: external_id}}} =
               BulkLoad.upsert_structure_note(params, ctx)

      assert external_id == data_structure.external_id
      assert [] = Repo.all(StructureNote)
    end

    test "filters out fields not in template", %{template: template} do
      claims = build(:claims, role: "admin")
      data_structure = insert(:data_structure)
      insert(:data_structure_version, data_structure: data_structure, type: template.name)

      params = %{
        "external_id" => data_structure.external_id,
        "df_content" => %{
          "field" => %{"value" => "test", "origin" => "file"},
          "non_existent_field" => %{"value" => "should_be_discarded", "origin" => "file"}
        },
        "_sheet" => template.name
      }

      ctx = %{
        claims: claims,
        lang: "en",
        to_status: "draft",
        opts: [],
        templates: %{
          template.name => %{content_schema: Format.flatten_content_fields(template.content)}
        }
      }

      assert {:created, {id, _details}} = BulkLoad.upsert_structure_note(params, ctx)

      assert [note] =
               StructureNote
               |> where(data_structure_id: ^data_structure.id)
               |> Repo.all()

      assert note.id == id
      assert note.df_content == %{"field" => %{"value" => "test", "origin" => "file"}}
      refute Map.has_key?(note.df_content, "non_existent_field")
    end

    test "merges new content with existing draft content", %{template: template} do
      claims = build(:claims, role: "admin")
      data_structure = insert(:data_structure)
      insert(:data_structure_version, data_structure: data_structure, type: template.name)

      existing_note =
        insert(:structure_note,
          data_structure: data_structure,
          status: :draft,
          version: 1,
          df_content: %{
            "field" => %{"value" => "existing_value", "origin" => "user"},
            "another_field" => %{"value" => "keep_this", "origin" => "user"}
          }
        )

      params = %{
        "external_id" => data_structure.external_id,
        "df_content" => %{"field" => %{"value" => "new_value", "origin" => "file"}},
        "_sheet" => template.name
      }

      ctx = %{
        claims: claims,
        lang: "en",
        to_status: "draft",
        opts: [],
        templates: %{
          template.name => %{content_schema: Format.flatten_content_fields(template.content)}
        }
      }

      assert {:updated, {id, _details}} = BulkLoad.upsert_structure_note(params, ctx)

      assert [note] =
               StructureNote
               |> where(data_structure_id: ^data_structure.id)
               |> Repo.all()

      assert note.id == id
      assert note.id != existing_note.id

      assert note.df_content == %{
               "field" => %{"value" => "new_value", "origin" => "file"},
               "another_field" => %{"value" => "keep_this", "origin" => "user"}
             }
    end

    test "merges new content with existing published content", %{template: template} do
      claims = build(:claims, role: "admin")
      data_structure = insert(:data_structure)
      insert(:data_structure_version, data_structure: data_structure, type: template.name)

      existing_note =
        insert(:structure_note,
          data_structure: data_structure,
          status: :published,
          version: 1,
          df_content: %{
            "field" => %{"value" => "published_value", "origin" => "user"},
            "another_field" => %{"value" => "keep_from_published", "origin" => "user"}
          }
        )

      params = %{
        "external_id" => data_structure.external_id,
        "df_content" => %{"field" => %{"value" => "new_value", "origin" => "file"}},
        "_sheet" => template.name
      }

      ctx = %{
        claims: claims,
        lang: "en",
        to_status: "draft",
        opts: [],
        templates: %{
          template.name => %{content_schema: Format.flatten_content_fields(template.content)}
        }
      }

      assert {:created, {id, _details}} = BulkLoad.upsert_structure_note(params, ctx)

      assert [published_note, draft_note] =
               StructureNote
               |> where(data_structure_id: ^data_structure.id)
               |> Repo.all()
               |> Enum.sort_by(& &1.version)

      assert published_note.id == existing_note.id
      assert draft_note.id == id

      assert draft_note.df_content == %{
               "field" => %{"value" => "new_value", "origin" => "file"},
               "another_field" => %{"value" => "keep_from_published", "origin" => "user"}
             }
    end

    test "creates structure note with valid content", %{template: template} do
      claims = build(:claims, role: "admin")
      data_structure = insert(:data_structure)
      insert(:data_structure_version, data_structure: data_structure, type: template.name)

      params = %{
        "external_id" => data_structure.external_id,
        "df_content" => %{"field" => %{"value" => "test", "origin" => "file"}},
        "_sheet" => template.name
      }

      ctx = %{
        claims: claims,
        lang: "en",
        to_status: "draft",
        opts: [],
        templates: %{
          template.name => %{content_schema: Format.flatten_content_fields(template.content)}
        }
      }

      assert {:created, {id, details}} = BulkLoad.upsert_structure_note(params, ctx)
      assert details.external_id == data_structure.external_id

      assert [note] =
               StructureNote
               |> where(data_structure_id: ^data_structure.id)
               |> Repo.all()

      assert note.id == id
      assert note.status == :draft
      assert note.version == 1
      assert note.df_content == %{"field" => %{"value" => "test", "origin" => "file"}}
    end

    test "validates field types and returns error for invalid values" do
      claims = build(:claims, role: "admin")

      content = [
        %{
          "name" => "group",
          "fields" => [
            %{
              "cardinality" => "?",
              "label" => "Date Field",
              "name" => "date_field",
              "type" => "date",
              "widget" => "date"
            },
            %{
              "cardinality" => "?",
              "label" => "Dropdown Field",
              "name" => "dropdown_field",
              "type" => "string",
              "widget" => "dropdown",
              "values" => %{"fixed" => ["option1", "option2", "option3"]}
            }
          ]
        }
      ]

      %{id: template_id} =
        template =
        CacheHelpers.insert_template(scope: "dd", content: content)

      CacheHelpers.insert_structure_type(name: template.name, template_id: template_id)

      data_structure = insert(:data_structure)
      insert(:data_structure_version, data_structure: data_structure, type: template.name)

      params = %{
        "external_id" => data_structure.external_id,
        "df_content" => %{
          "date_field" => %{"value" => "invalid-date-format", "origin" => "file"},
          "dropdown_field" => %{"value" => "invalid_option", "origin" => "file"}
        },
        "_sheet" => template.name
      }

      ctx = %{
        claims: claims,
        lang: "en",
        to_status: "draft",
        opts: [],
        templates: %{
          template.name => %{content_schema: Format.flatten_content_fields(template.content)}
        }
      }

      result = BulkLoad.upsert_structure_note(params, ctx)

      assert match?({:error, {"field_validation_error", _}}, result)

      assert [] = Repo.all(StructureNote)
    end

    test "created response includes data_structure_id in details", %{
      template: template
    } do
      claims = build(:claims, role: "admin")

      data_structure =
        insert(:data_structure, external_id: "bulk_load_#{System.unique_integer([:positive])}")

      insert(:data_structure_version, data_structure: data_structure, type: template.name)

      params = %{
        "external_id" => data_structure.external_id,
        "df_content" => %{"field" => %{"value" => "test", "origin" => "file"}},
        "_sheet" => template.name
      }

      ctx = %{
        claims: claims,
        lang: "en",
        to_status: "draft",
        opts: [],
        templates: %{
          template.name => %{content_schema: Format.flatten_content_fields(template.content)}
        }
      }

      assert {:created, {_id, details}} = BulkLoad.upsert_structure_note(params, ctx)
      assert details.data_structure_id == data_structure.id
      assert details.external_id == data_structure.external_id
    end

    test "updated response includes data_structure_id in details", %{
      template: template
    } do
      claims = build(:claims, role: "admin")

      data_structure =
        insert(:data_structure, external_id: "bulk_load_#{System.unique_integer([:positive])}")

      insert(:data_structure_version, data_structure: data_structure, type: template.name)

      insert(:structure_note,
        data_structure: data_structure,
        status: :draft,
        version: 1,
        df_content: %{"field" => %{"value" => "old", "origin" => "user"}}
      )

      params = %{
        "external_id" => data_structure.external_id,
        "df_content" => %{"field" => %{"value" => "new", "origin" => "file"}},
        "_sheet" => template.name
      }

      ctx = %{
        claims: claims,
        lang: "en",
        to_status: "draft",
        opts: [],
        templates: %{
          template.name => %{content_schema: Format.flatten_content_fields(template.content)}
        }
      }

      assert {:updated, {_id, details}} = BulkLoad.upsert_structure_note(params, ctx)
      assert details.data_structure_id == data_structure.id
      assert details.external_id == data_structure.external_id
    end

    test "unchanged response includes data_structure_id in details", %{
      template: template
    } do
      claims = build(:claims, role: "admin")

      data_structure =
        insert(:data_structure, external_id: "bulk_load_#{System.unique_integer([:positive])}")

      insert(:data_structure_version, data_structure: data_structure, type: template.name)

      insert(:structure_note,
        data_structure: data_structure,
        status: :draft,
        version: 1,
        df_content: %{"field" => %{"value" => "same", "origin" => "user"}}
      )

      params = %{
        "external_id" => data_structure.external_id,
        "df_content" => %{"field" => %{"value" => "same", "origin" => "file"}},
        "_sheet" => template.name
      }

      ctx = %{
        claims: claims,
        lang: "en",
        to_status: "draft",
        opts: [],
        templates: %{
          template.name => %{content_schema: Format.flatten_content_fields(template.content)}
        }
      }

      assert {:unchanged, details} = BulkLoad.upsert_structure_note(params, ctx)
      assert details.data_structure_id == data_structure.id
      assert details.external_id == data_structure.external_id
    end

    test "pending_approval_conflict error includes data_structure_id in details", %{
      template: template
    } do
      claims = build(:claims, role: "admin")

      data_structure =
        insert(:data_structure, external_id: "bulk_load_#{System.unique_integer([:positive])}")

      insert(:data_structure_version, data_structure: data_structure, type: template.name)

      insert(:structure_note,
        data_structure: data_structure,
        status: :pending_approval,
        version: 1,
        df_content: %{"field" => %{"value" => "existing", "origin" => "user"}}
      )

      params = %{
        "external_id" => data_structure.external_id,
        "df_content" => %{"field" => %{"value" => "new", "origin" => "file"}},
        "_sheet" => template.name
      }

      ctx = %{
        claims: claims,
        lang: "en",
        to_status: "draft",
        opts: [],
        templates: %{
          template.name => %{content_schema: Format.flatten_content_fields(template.content)}
        }
      }

      assert {:error, {"pending_approval_conflict", details}} =
               BulkLoad.upsert_structure_note(params, ctx)

      assert details.data_structure_id == data_structure.id
      assert details.external_id == data_structure.external_id
    end

    test "unauthorized error includes data_structure_id in details", %{
      template: template
    } do
      claims = build(:claims, role: "user")

      data_structure =
        insert(:data_structure, external_id: "bulk_load_#{System.unique_integer([:positive])}")

      insert(:data_structure_version, data_structure: data_structure, type: template.name)

      params = %{
        "external_id" => data_structure.external_id,
        "df_content" => %{"field" => %{"value" => "test", "origin" => "file"}},
        "_sheet" => template.name
      }

      ctx = %{
        claims: claims,
        lang: "en",
        to_status: "draft",
        opts: [],
        templates: %{
          template.name => %{content_schema: Format.flatten_content_fields(template.content)}
        }
      }

      assert {:error, {"unauthorized", details}} =
               BulkLoad.upsert_structure_note(params, ctx)

      assert details.data_structure_id == data_structure.id
      assert details.external_id == data_structure.external_id
    end

    test "field_validation_error includes data_structure_id in details" do
      claims = build(:claims, role: "admin")

      content = [
        %{
          "name" => "group",
          "fields" => [
            %{
              "cardinality" => "?",
              "label" => "Date Field",
              "name" => "date_field",
              "type" => "date",
              "widget" => "date"
            },
            %{
              "cardinality" => "?",
              "label" => "Dropdown Field",
              "name" => "dropdown_field",
              "type" => "string",
              "widget" => "dropdown",
              "values" => %{"fixed" => ["option1", "option2", "option3"]}
            }
          ]
        }
      ]

      %{id: template_id, name: date_template_name} =
        template =
        CacheHelpers.insert_template(scope: "dd", content: content)

      CacheHelpers.insert_structure_type(name: date_template_name, template_id: template_id)

      data_structure =
        insert(:data_structure, external_id: "bulk_load_#{System.unique_integer([:positive])}")

      insert(:data_structure_version, data_structure: data_structure, type: date_template_name)

      params = %{
        "external_id" => data_structure.external_id,
        "df_content" => %{
          "date_field" => %{"value" => "invalid-date-format", "origin" => "file"},
          "dropdown_field" => %{"value" => "invalid_option", "origin" => "file"}
        },
        "_sheet" => date_template_name
      }

      ctx = %{
        claims: claims,
        lang: "en",
        to_status: "draft",
        opts: [],
        templates: %{
          date_template_name => %{content_schema: Format.flatten_content_fields(template.content)}
        }
      }

      assert {:error, {"field_validation_error", details}} =
               BulkLoad.upsert_structure_note(params, ctx)

      assert details.data_structure_id == data_structure.id
      assert details.external_id == data_structure.external_id
    end

    test "data_structure_not_found error does not include data_structure_id" do
      claims = build(:claims, role: "admin")

      params = %{
        "external_id" => "non_existent_id",
        "df_content" => %{"field" => %{"value" => "test", "origin" => "file"}},
        "_sheet" => "sheet"
      }

      ctx = %{claims: claims, to_status: "draft", opts: [], templates: %{}}

      assert {:error, {"data_structure_not_found", details}} =
               BulkLoad.upsert_structure_note(params, ctx)

      assert details.external_id == "non_existent_id"
      refute Map.has_key?(details, :data_structure_id)
    end

    test "created response includes changes with status and df_content when creating new note", %{
      template: template
    } do
      claims = build(:claims, role: "admin")
      data_structure = insert(:data_structure)
      insert(:data_structure_version, data_structure: data_structure, type: template.name)

      params = %{
        "external_id" => data_structure.external_id,
        "df_content" => %{
          "field" => %{"value" => "test", "origin" => "file"},
          "another_field" => %{"value" => "other", "origin" => "file"}
        },
        "_sheet" => template.name
      }

      ctx = %{
        claims: claims,
        lang: "en",
        to_status: "draft",
        opts: [],
        templates: %{
          template.name => %{content_schema: Format.flatten_content_fields(template.content)}
        }
      }

      assert {:created, {_id, details}} = BulkLoad.upsert_structure_note(params, ctx)
      assert %{changes: changes} = details
      assert changes.status == "draft"
      assert %{"field" => _, "another_field" => _} = changes.df_content
      assert changes.df_content["field"] == %{"value" => "test", "origin" => "file"}
      assert changes.df_content["another_field"] == %{"value" => "other", "origin" => "file"}
    end

    test "created response includes changes when creating new version from published note", %{
      template: template
    } do
      claims = build(:claims, role: "admin")
      data_structure = insert(:data_structure)
      insert(:data_structure_version, data_structure: data_structure, type: template.name)

      insert(:structure_note,
        data_structure: data_structure,
        status: :published,
        version: 1,
        df_content: %{"field" => %{"value" => "old", "origin" => "user"}}
      )

      params = %{
        "external_id" => data_structure.external_id,
        "df_content" => %{"field" => %{"value" => "new_from_file", "origin" => "file"}},
        "_sheet" => template.name
      }

      ctx = %{
        claims: claims,
        lang: "en",
        to_status: "draft",
        opts: [],
        templates: %{
          template.name => %{content_schema: Format.flatten_content_fields(template.content)}
        }
      }

      assert {:created, {_id, details}} = BulkLoad.upsert_structure_note(params, ctx)
      assert %{changes: changes} = details
      assert changes.status == "draft"
      assert changes.df_content["field"] == %{"value" => "new_from_file", "origin" => "file"}
    end

    test "updated response includes changes with status and only changed df_content fields", %{
      template: template
    } do
      claims = build(:claims, role: "admin")
      data_structure = insert(:data_structure)
      insert(:data_structure_version, data_structure: data_structure, type: template.name)

      insert(:structure_note,
        data_structure: data_structure,
        status: :draft,
        version: 1,
        df_content: %{
          "field" => %{"value" => "unchanged", "origin" => "user"},
          "another_field" => %{"value" => "old_value", "origin" => "user"}
        }
      )

      params = %{
        "external_id" => data_structure.external_id,
        "df_content" => %{
          "field" => %{"value" => "unchanged", "origin" => "file"},
          "another_field" => %{"value" => "new_value", "origin" => "file"}
        },
        "_sheet" => template.name
      }

      ctx = %{
        claims: claims,
        lang: "en",
        to_status: "draft",
        opts: [],
        templates: %{
          template.name => %{content_schema: Format.flatten_content_fields(template.content)}
        }
      }

      assert {:updated, {_id, details}} = BulkLoad.upsert_structure_note(params, ctx)
      assert %{changes: changes} = details
      assert changes.status == "draft"
      assert map_size(changes.df_content) == 1
      assert changes.df_content["another_field"] == %{"value" => "new_value", "origin" => "file"}
      refute Map.has_key?(changes.df_content, "field")
    end

    test "created response includes changes with published status when user has publish permission",
         %{template: template} do
      claims = build(:claims, role: "admin")
      data_structure = insert(:data_structure)
      insert(:data_structure_version, data_structure: data_structure, type: template.name)

      params = %{
        "external_id" => data_structure.external_id,
        "df_content" => %{"field" => %{"value" => "test", "origin" => "file"}},
        "_sheet" => template.name
      }

      ctx = %{
        claims: claims,
        lang: "en",
        to_status: "published",
        opts: [],
        templates: %{
          template.name => %{content_schema: Format.flatten_content_fields(template.content)}
        }
      }

      assert {:created, {_id, details}} = BulkLoad.upsert_structure_note(params, ctx)
      assert details.changes.status == "published"
      assert details.changes.df_content["field"] == %{"value" => "test", "origin" => "file"}
    end
  end

  describe "upsert_structure_note/2 structure_note_creation_error from changeset" do
    test "returns error when df_content field has invalid enum value", %{
      template: template
    } do
      claims = build(:claims, role: "admin")
      data_structure = insert(:data_structure)
      insert(:data_structure_version, data_structure: data_structure, type: template.name)

      template_with_enum =
        CacheHelpers.insert_template(
          scope: "dd",
          content: [
            %{
              "name" => "group",
              "fields" => [
                %{
                  "cardinality" => "1",
                  "label" => "List Field",
                  "name" => "list_field",
                  "type" => "string",
                  "widget" => "dropdown",
                  "values" => %{"fixed" => ["option1", "option2", "option3"]}
                }
              ]
            }
          ]
        )

      %{id: enum_template_id} = template_with_enum

      CacheHelpers.insert_structure_type(
        name: template_with_enum.name,
        template_id: enum_template_id
      )

      data_structure_with_enum = insert(:data_structure)

      insert(:data_structure_version,
        data_structure: data_structure_with_enum,
        type: template_with_enum.name
      )

      params = %{
        "external_id" => data_structure_with_enum.external_id,
        "df_content" => %{
          "list_field" => %{"value" => "invalid_option", "origin" => "file"}
        },
        "_sheet" => template_with_enum.name
      }

      ctx = %{
        claims: claims,
        lang: "en",
        to_status: "draft",
        opts: [],
        templates: %{
          template_with_enum.name => %{
            content_schema: Format.flatten_content_fields(template_with_enum.content)
          }
        }
      }

      {:error, {"field_validation_error", details}} = BulkLoad.upsert_structure_note(params, ctx)

      assert details.external_id == data_structure_with_enum.external_id
      assert details.data_structure_id == data_structure_with_enum.id
      assert details.errors == [%{message: "is invalid", field: :list_field}]
    end

    test "returns error when df_content field has invalid type", %{template: template} do
      claims = build(:claims, role: "admin")
      data_structure = insert(:data_structure)
      insert(:data_structure_version, data_structure: data_structure, type: template.name)

      template_with_integer =
        CacheHelpers.insert_template(
          scope: "dd",
          content: [
            %{
              "name" => "group",
              "fields" => [
                %{
                  "cardinality" => "1",
                  "label" => "Integer Field",
                  "name" => "integer_field",
                  "type" => "integer"
                }
              ]
            }
          ]
        )

      %{id: int_template_id} = template_with_integer

      CacheHelpers.insert_structure_type(
        name: template_with_integer.name,
        template_id: int_template_id
      )

      data_structure_with_int = insert(:data_structure)

      insert(:data_structure_version,
        data_structure: data_structure_with_int,
        type: template_with_integer.name
      )

      params = %{
        "external_id" => data_structure_with_int.external_id,
        "df_content" => %{
          "integer_field" => %{"value" => "not_a_number", "origin" => "file"}
        },
        "_sheet" => template_with_integer.name
      }

      ctx = %{
        claims: claims,
        lang: "en",
        to_status: "draft",
        opts: [],
        templates: %{
          template_with_integer.name => %{
            content_schema: Format.flatten_content_fields(template_with_integer.content)
          }
        }
      }

      {:error, {"field_validation_error", details}} = BulkLoad.upsert_structure_note(params, ctx)
      assert details.external_id == data_structure_with_int.external_id
      assert details.data_structure_id == data_structure_with_int.id
      assert is_list(details.errors)
      assert details.errors == [%{message: "Integer Field is invalid", field: :integer_field}]
    end

    test "returns error when df_content has multiple validation errors", %{template: template} do
      claims = build(:claims, role: "admin")
      data_structure = insert(:data_structure)
      insert(:data_structure_version, data_structure: data_structure, type: template.name)

      template_with_multiple =
        CacheHelpers.insert_template(
          scope: "dd",
          content: [
            %{
              "name" => "group",
              "fields" => [
                %{
                  "cardinality" => "1",
                  "label" => "List Field",
                  "name" => "list_field",
                  "type" => "string",
                  "widget" => "dropdown",
                  "values" => %{"fixed" => ["option1", "option2"]}
                },
                %{
                  "cardinality" => "1",
                  "label" => "Integer Field",
                  "name" => "integer_field",
                  "type" => "integer"
                }
              ]
            }
          ]
        )

      %{id: multi_template_id} = template_with_multiple

      CacheHelpers.insert_structure_type(
        name: template_with_multiple.name,
        template_id: multi_template_id
      )

      data_structure_with_multi = insert(:data_structure)

      insert(:data_structure_version,
        data_structure: data_structure_with_multi,
        type: template_with_multiple.name
      )

      params = %{
        "external_id" => data_structure_with_multi.external_id,
        "df_content" => %{
          "list_field" => %{"value" => "invalid_option", "origin" => "file"},
          "integer_field" => %{"value" => "not_a_number", "origin" => "file"}
        },
        "_sheet" => template_with_multiple.name
      }

      ctx = %{
        claims: claims,
        lang: "en",
        to_status: "draft",
        opts: [],
        templates: %{
          template_with_multiple.name => %{
            content_schema: Format.flatten_content_fields(template_with_multiple.content)
          }
        }
      }

      {:error, {"field_validation_error", details}} = BulkLoad.upsert_structure_note(params, ctx)

      assert details.external_id == data_structure_with_multi.external_id
      assert details.data_structure_id == data_structure_with_multi.id
      assert is_list(details.errors)

      assert Enum.find(details.errors, fn error -> error.field == :list_field end).message ==
               "is invalid"

      assert Enum.find(details.errors, fn error -> error.field == :integer_field end).message ==
               "Integer Field is invalid"
    end
  end

  describe "bulk_load/2" do
    setup do
      IndexWorkerMock.clear()
      :ok
    end

    test "processes row by row and records unauthorized as ERROR while continuing with authorized rows",
         %{template: template} do
      claims = build(:claims, role: "user")
      domain_with_permission = CacheHelpers.insert_domain()
      domain_without_permission = CacheHelpers.insert_domain()

      data_structure_authorized =
        insert(:data_structure, domain_ids: [domain_with_permission.id])

      data_structure_unauthorized =
        insert(:data_structure, domain_ids: [domain_without_permission.id])

      insert(:data_structure_version,
        data_structure: data_structure_authorized,
        type: template.name
      )

      insert(:data_structure_version,
        data_structure: data_structure_unauthorized,
        type: template.name
      )

      CacheHelpers.put_session_permissions(
        claims,
        domain_with_permission.id,
        [:create_structure_note, :edit_structure_note, :view_data_structure]
      )

      job_id = System.unique_integer([:positive])

      # Expectation for authorized info event (created or updated)
      UploadJobs.create_info(
        &Mox.expect/4,
        job_id,
        %{
          type: "created",
          details: %{
            external_id: data_structure_authorized.external_id
          }
        },
        {:ok, nil}
      )

      # Expectation for unauthorized error event
      UploadJobs.create_error(
        &Mox.expect/4,
        job_id,
        %{
          type: "unauthorized",
          details: %{
            external_id: data_structure_unauthorized.external_id,
            data_structure_id: data_structure_unauthorized.id
          },
          row_number: 3,
          sheet: template.name
        }
      )

      sheets = %{
        template.name =>
          {["external_id", "field"],
           [
             [data_structure_authorized.external_id, "value_authorized"],
             [data_structure_unauthorized.external_id, "value_unauthorized"]
           ]}
      }

      opts = %{
        claims: claims,
        lang: "en",
        to_status: "draft",
        job_id: job_id,
        impl_for: struct(StructureNote),
        templates: %{
          template.name => %{content_schema: Format.flatten_content_fields(template.content)}
        }
      }

      assert {:ok, result} = XLSXBulkLoad.bulk_load(sheets, opts)
      assert result.insert_count + result.update_count == 1
      assert result.error_count == 1
    end

    test "calls reindex with created structure note ids", %{template: template} do
      claims = build(:claims, role: "admin")
      data_structure_1 = insert(:data_structure)
      data_structure_2 = insert(:data_structure)

      dsv1 =
        insert(:data_structure_version, data_structure: data_structure_1, type: template.name)

      dsv2 =
        insert(:data_structure_version, data_structure: data_structure_2, type: template.name)

      job_id = System.unique_integer([:positive])

      UploadJobs.create_info(&Mox.expect/4, job_id, %{
        type: "created",
        details: %{
          external_id: data_structure_1.external_id,
          changes: %{
            status: "draft",
            df_content: %{"field" => %{"origin" => "file", "value" => "value1"}}
          },
          data_structure_id: dsv1.data_structure_id
        },
        row_number: 2,
        sheet: template.name
      })

      UploadJobs.create_info(&Mox.expect/4, job_id, %{
        type: "created",
        details: %{
          external_id: data_structure_2.external_id,
          changes: %{
            status: "draft",
            df_content: %{"field" => %{"origin" => "file", "value" => "value2"}}
          },
          data_structure_id: dsv2.data_structure_id
        },
        row_number: 3,
        sheet: template.name
      })

      sheets = %{
        template.name =>
          {["external_id", "field"],
           [
             [data_structure_1.external_id, "value1"],
             [data_structure_2.external_id, "value2"]
           ]}
      }

      opts = %{
        claims: claims,
        lang: "en",
        to_status: "draft",
        job_id: job_id,
        impl_for: struct(StructureNote),
        templates: %{
          template.name => %{content_schema: Format.flatten_content_fields(template.content)}
        }
      }

      assert {:ok, %{insert_count: 2}} = XLSXBulkLoad.bulk_load(sheets, opts)

      assert [{:reindex, :structure_notes, ids}] = IndexWorkerMock.calls()
      assert length(ids) == 2
      assert Enum.all?(ids, &is_integer/1)
    end

    test "calls reindex with updated structure note ids", %{template: template} do
      claims = build(:claims, role: "admin")
      data_structure = insert(:data_structure)
      insert(:data_structure_version, data_structure: data_structure, type: template.name)

      existing_note =
        insert(:structure_note,
          data_structure: data_structure,
          status: :draft,
          version: 1,
          df_content: %{"field" => %{"value" => "old_value", "origin" => "user"}}
        )

      job_id = System.unique_integer([:positive])

      UploadJobs.create_info(&Mox.expect/4, job_id, %{
        type: "updated",
        details: %{
          external_id: data_structure.external_id,
          changes: %{
            status: "draft",
            df_content: %{"field" => %{"origin" => "file", "value" => "new_value"}}
          },
          data_structure_id: data_structure.id
        },
        row_number: 2,
        sheet: template.name
      })

      sheets = %{
        template.name => {["external_id", "field"], [[data_structure.external_id, "new_value"]]}
      }

      opts = %{
        claims: claims,
        lang: "en",
        to_status: "draft",
        job_id: job_id,
        impl_for: struct(StructureNote),
        templates: %{
          template.name => %{content_schema: Format.flatten_content_fields(template.content)}
        }
      }

      assert {:ok, %{update_count: 1}} = XLSXBulkLoad.bulk_load(sheets, opts)

      assert [{:reindex, :structure_notes, [id]}] = IndexWorkerMock.calls()
      assert id != existing_note.id
      assert is_integer(id)
    end

    test "calls reindex with both created and updated structure note ids", %{
      template: template
    } do
      claims = build(:claims, role: "admin")
      data_structure_1 = insert(:data_structure)
      data_structure_2 = insert(:data_structure)

      insert(:data_structure_version, data_structure: data_structure_1, type: template.name)
      insert(:data_structure_version, data_structure: data_structure_2, type: template.name)

      existing_note =
        insert(:structure_note,
          data_structure: data_structure_1,
          status: :draft,
          version: 1,
          df_content: %{"field" => %{"value" => "old_value", "origin" => "user"}}
        )

      job_id = System.unique_integer([:positive])

      UploadJobs.create_info(&Mox.expect/4, job_id, %{
        type: "updated",
        details: %{
          external_id: data_structure_1.external_id,
          changes: %{
            status: "draft",
            df_content: %{"field" => %{"origin" => "file", "value" => "updated_value"}}
          },
          data_structure_id: data_structure_1.id
        },
        row_number: 2,
        sheet: template.name
      })

      UploadJobs.create_info(&Mox.expect/4, job_id, %{
        type: "created",
        details: %{
          external_id: data_structure_2.external_id,
          changes: %{
            status: "draft",
            df_content: %{"field" => %{"origin" => "file", "value" => "new_value"}}
          },
          data_structure_id: data_structure_2.id
        },
        row_number: 3,
        sheet: template.name
      })

      sheets = %{
        template.name =>
          {["external_id", "field"],
           [
             [data_structure_1.external_id, "updated_value"],
             [data_structure_2.external_id, "new_value"]
           ]}
      }

      opts = %{
        claims: claims,
        lang: "en",
        to_status: "draft",
        job_id: job_id,
        impl_for: struct(StructureNote),
        templates: %{
          template.name => %{content_schema: Format.flatten_content_fields(template.content)}
        }
      }

      assert {:ok, %{insert_count: 1, update_count: 1}} =
               XLSXBulkLoad.bulk_load(sheets, opts)

      assert [{:reindex, :structure_notes, ids}] = IndexWorkerMock.calls()
      assert length(ids) == 2
      assert existing_note.id not in ids
      assert Enum.all?(ids, &is_integer/1)
    end

    test "does not call reindex when no structure notes are created or updated", %{
      template: template
    } do
      claims = build(:claims, role: "admin")
      data_structure = insert(:data_structure)
      insert(:data_structure_version, data_structure: data_structure, type: template.name)

      insert(:structure_note,
        data_structure: data_structure,
        status: :draft,
        version: 1,
        df_content: %{"field" => %{"value" => "test", "origin" => "user"}}
      )

      job_id = System.unique_integer([:positive])

      UploadJobs.create_info(&Mox.expect/4, job_id, %{
        type: "unchanged",
        details: %{
          external_id: data_structure.external_id,
          data_structure_id: data_structure.id
        },
        row_number: 2,
        sheet: template.name
      })

      sheets = %{
        template.name => {["external_id", "field"], [[data_structure.external_id, "test"]]}
      }

      opts = %{
        claims: claims,
        lang: "en",
        to_status: "draft",
        job_id: job_id,
        impl_for: struct(StructureNote),
        templates: %{
          template.name => %{content_schema: Format.flatten_content_fields(template.content)}
        }
      }

      assert {:ok, %{unchanged_count: 1}} = XLSXBulkLoad.bulk_load(sheets, opts)

      assert [] = IndexWorkerMock.calls()
    end
  end
end
