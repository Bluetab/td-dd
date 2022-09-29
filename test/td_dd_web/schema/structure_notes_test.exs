defmodule TdDdWeb.Schema.StructureNotesTest do
  use TdDdWeb.ConnCase

  @query """
  query StructureNotes($filter: StructureNotesFilter) {
    structureNotes(filter: $filter) {
      id
      status
      dataStructure {
        domains {
          name
        }
      }
    }
  }
  """

  describe "structureNotes query" do
    @tag authentication: [role: "admin"]
    test "returns all data when queried by admin role", %{conn: conn} do
      %{id: expected_id, status: expected_status} = insert(:structure_note)

      assert %{"data" => %{"structureNotes" => structure_notes}} =
               conn
               |> post("/api/v2", %{"query" => @query})
               |> json_response(:ok)

      assert [%{"id" => id, "status" => status}] = structure_notes
      assert id == to_string(expected_id)
      assert status == to_string(expected_status)
    end

    @tag authentication: [
           role: "user",
           permissions: [:publish_structure_note, :view_data_structure]
         ]
    test "user with :publish_structure_note permission will return notes with status :pending_approval",
         %{conn: conn, domain: domain} do
      %{id: id} =
        insert(:structure_note,
          data_structure: build(:data_structure, domain_ids: [domain.id]),
          status: :pending_approval
        )

      insert(:structure_note, status: :pending_approval)

      insert(:structure_note,
        data_structure: build(:data_structure, domain_ids: [domain.id]),
        status: :draft
      )

      assert %{"data" => %{"structureNotes" => structure_notes}} =
               conn
               |> post("/api/v2", %{"query" => @query})
               |> json_response(:ok)

      string_id = "#{id}"
      assert [%{"id" => ^string_id}] = structure_notes
    end

    @tag authentication: [
           role: "user",
           permissions: [:publish_structure_note_from_draft, :view_data_structure]
         ]
    test "user with :publish_structure_note_from_draft permission will return notes with status :draft",
         %{conn: conn, domain: domain} do
      %{id: id} =
        insert(:structure_note,
          data_structure: build(:data_structure, domain_ids: [domain.id]),
          status: :draft
        )

      insert(:structure_note, status: :draft)

      insert(:structure_note,
        data_structure: build(:data_structure, domain_ids: [domain.id]),
        status: :published
      )

      assert %{"data" => %{"structureNotes" => structure_notes}} =
               conn
               |> post("/api/v2", %{"query" => @query})
               |> json_response(:ok)

      string_id = "#{id}"
      assert [%{"id" => ^string_id}] = structure_notes
    end

    @tag authentication: [role: "user", permissions: [:edit_structure_note, :view_data_structure]]
    test "user with :edit_structure_note permission will return notes with status :draft",
         %{conn: conn, domain: domain} do
      %{id: id} =
        insert(:structure_note,
          data_structure: build(:data_structure, domain_ids: [domain.id]),
          status: :draft
        )

      insert(:structure_note, status: :draft)

      insert(:structure_note,
        data_structure: build(:data_structure, domain_ids: [domain.id]),
        status: :published
      )

      assert %{"data" => %{"structureNotes" => structure_notes}} =
               conn
               |> post("/api/v2", %{"query" => @query})
               |> json_response(:ok)

      string_id = "#{id}"
      assert [%{"id" => ^string_id}] = structure_notes
    end

    @tag authentication: [
           role: "user",
           permissions: [:unreject_structure_note, :view_data_structure]
         ]
    test "user with :unreject_structure_note permission will return notes with status :rejected",
         %{conn: conn, domain: domain} do
      %{id: id} =
        insert(:structure_note,
          data_structure: build(:data_structure, domain_ids: [domain.id]),
          status: :rejected
        )

      insert(:structure_note, status: :rejected)

      insert(:structure_note,
        data_structure: build(:data_structure, domain_ids: [domain.id]),
        status: :published
      )

      assert %{"data" => %{"structureNotes" => structure_notes}} =
               conn
               |> post("/api/v2", %{"query" => @query})
               |> json_response(:ok)

      string_id = "#{id}"
      assert [%{"id" => ^string_id}] = structure_notes
    end

    @tag authentication: [role: "admin"]
    test "filters structure notes by status",
         %{conn: conn} do
      %{id: id} = insert(:structure_note, status: :rejected)
      insert(:structure_note, status: :draft)
      insert(:structure_note, status: :published)

      assert %{"data" => %{"structureNotes" => structure_notes}} =
               conn
               |> post("/api/v2", %{
                 "query" => @query,
                 "variables" => %{
                   "filter" => %{
                     "statuses" => ["rejected"]
                   }
                 }
               })
               |> json_response(:ok)

      string_id = "#{id}"
      assert [%{"id" => ^string_id}] = structure_notes
    end

    @tag authentication: [role: "admin"]
    test "filters structure notes by system_id",
         %{conn: conn} do
      %{id: id, data_structure: %{system_id: system_id}} = insert(:structure_note)
      insert(:structure_note)

      assert %{"data" => %{"structureNotes" => structure_notes}} =
               conn
               |> post("/api/v2", %{
                 "query" => @query,
                 "variables" => %{
                   "filter" => %{
                     "system_ids" => [system_id]
                   }
                 }
               })
               |> json_response(:ok)

      string_id = "#{id}"
      assert [%{"id" => ^string_id}] = structure_notes
    end

    @tag authentication: [role: "admin"]
    test "filters structure notes by domain_id",
         %{conn: conn} do
      domain_id = 10

      %{id: id} =
        insert(:structure_note,
          data_structure: build(:data_structure, domain_ids: [domain_id])
        )

      insert(:structure_note)

      assert %{"data" => %{"structureNotes" => structure_notes}} =
               conn
               |> post("/api/v2", %{
                 "query" => @query,
                 "variables" => %{
                   "filter" => %{
                     "domain_ids" => [domain_id]
                   }
                 }
               })
               |> json_response(:ok)

      string_id = "#{id}"
      assert [%{"id" => ^string_id}] = structure_notes
    end

    @tag authentication: [role: "admin"]
    test "empty domain ids filters returns all results",
         %{conn: conn} do
      domain_id = 10

      %{id: id} =
        insert(:structure_note,
          data_structure: build(:data_structure, domain_ids: [domain_id])
        )

      assert %{"data" => %{"structureNotes" => structure_notes}} =
               conn
               |> post("/api/v2", %{
                 "query" => @query,
                 "variables" => %{
                   "filter" => %{
                     "domain_ids" => []
                   }
                 }
               })
               |> json_response(:ok)

      string_id = "#{id}"
      assert [%{"id" => ^string_id}] = structure_notes
    end

    @tag authentication: [role: "admin"]
    test "returns data_structure domain",
         %{conn: conn} do
      %{name: domain_name, id: domain_id} = CacheHelpers.insert_domain()
      insert(:structure_note, data_structure: build(:data_structure, domain_ids: [domain_id]))

      assert %{
               "data" => %{
                 "structureNotes" => [
                   %{
                     "dataStructure" => %{"domains" => domains}
                   }
                 ]
               }
             } =
               conn
               |> post("/api/v2", %{"query" => @query})
               |> json_response(:ok)

      assert [%{"name" => ^domain_name}] = domains
    end
  end
end
