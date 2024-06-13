defmodule TdDdWeb.Schema.SourcesTest do
  use TdDdWeb.ConnCase

  @moduletag sandbox: :shared

  @valid_config %{
    "string" => %{"value" => "foo", "origin" => "user"},
    "list" => %{"value" => "two", "origin" => "user"}
  }

  @source_with_template """
  query Source($id: ID!) {
    source(id: $id) {
      id
      active
      config
      externalId
      type
      template {
        id
        name
        label
        scope
        content
        updatedAt
      }
    }
  }
  """

  @source_with_jobs """
  query SourceWithJobs($id: ID!) {
    source(id: $id) {
      id
      jobs {
        id
        externalId
        type
        parameters
        insertedAt
        updatedAt
        events(limit: 1) {
          id
          type
          message
          insertedAt
        }
      }
    }
  }
  """

  @sources """
  query Sources {
    sources {
      id
      externalId
    }
  }
  """

  @deleted_sources """
  query DeletedSources {
    sources(deleted: true) {
      id
      externalId
    }
  }
  """

  @sources_with_events """
  query Sources($eventLimit: Int) {
    sources {
      id
      externalId
      events(limit: $eventLimit) {
        id
        type
        message
        insertedAt
      }
    }
  }
  """

  @enable_source """
  mutation EnableSource($id: ID!) {
    enableSource(id: $id) {
      id
      externalId
      active
    }
  }
  """

  @disable_source """
  mutation DisableSource($id: ID!) {
    disableSource(id: $id) {
      id
      externalId
      active
    }
  }
  """

  @create_source """
  mutation CreateSource($source: CreateSourceInput!) {
    createSource(source: $source) {
      id
      config
    }
  }
  """

  @update_source """
  mutation UpdateSource($source: UpdateSourceInput!) {
    updateSource(source: $source) {
      id
      config
    }
  }
  """

  @delete_source """
  mutation DeleteSource($id: ID!) {
    deleteSource(id: $id) {
      id
      externalId
    }
  }
  """

  defp create_template(%{domain: domain_name}) when is_binary(domain_name) do
    [
      domain: CacheHelpers.insert_domain(%{name: domain_name}),
      template:
        CacheHelpers.insert_template(
          content: [
            build(:template_group,
              fields: [build(:template_field, name: "domain", type: "domain")]
            )
          ]
        )
    ]
  end

  defp create_template(_) do
    [template: CacheHelpers.insert_template()]
  end

  defp create_source(%{domain: %{id: domain_id}, template: %{name: source_type}}) do
    config = %{"foo" => "bar", "domain" => domain_id}
    [source: insert(:source, config: config, type: source_type)]
  end

  defp create_source(%{template: %{name: source_type}}) do
    [source: insert(:source, config: @valid_config, type: source_type)]
  end

  describe "source queries" do
    setup [:create_template, :create_source]

    @tag authentication: [role: "user"]
    test "returns forbidden when queried by user role", %{conn: conn} do
      assert %{"data" => data, "errors" => errors} =
               conn
               |> post("/api/v2", %{
                 "query" => @source_with_template,
                 "variables" => %{"id" => 123}
               })
               |> json_response(:ok)

      assert data == %{"source" => nil}
      assert [%{"message" => "forbidden"}] = errors
    end

    @tag authentication: [role: "user", permissions: ["manage_raw_quality_rule_implementations"]]
    test "returns data when queried by user with permissions", %{
      conn: conn,
      source: %{id: source_id}
    } do
      assert %{"data" => data} =
               response =
               conn
               |> post("/api/v2", %{
                 "query" => @sources,
                 "variables" => %{"id" => source_id}
               })
               |> json_response(:ok)

      assert response["errors"] == nil
      assert %{"sources" => [source]} = data
      assert %{"id" => id} = source
      assert id == to_string(source_id)
    end

    @tag authentication: [role: "admin"]
    test "returns data when queried by admin role", %{
      conn: conn,
      source: %{config: config, id: source_id},
      template: %{content: content}
    } do
      assert %{"data" => data} =
               response =
               conn
               |> post("/api/v2", %{
                 "query" => @source_with_template,
                 "variables" => %{"id" => source_id}
               })
               |> json_response(:ok)

      assert response["errors"] == nil
      assert %{"source" => source} = data
      assert %{"id" => id, "config" => ^config, "template" => template} = source
      assert id == to_string(source_id)
      assert %{"content" => ^content} = template
    end

    @tag authentication: [role: "admin"]
    @tag domain: "foo"
    test "does not enrich domain configuration from cache", %{
      conn: conn,
      source: %{id: source_id},
      domain: %{id: domain_id}
    } do
      assert %{"data" => data} =
               response =
               conn
               |> post("/api/v2", %{
                 "query" => @source_with_template,
                 "variables" => %{"id" => source_id}
               })
               |> json_response(:ok)

      assert response["errors"] == nil
      assert %{"source" => source} = data
      assert %{"config" => config} = source
      assert %{"domain" => ^domain_id} = config
    end

    @tag authentication: [role: "admin"]
    test "retrieves jobs with most recently updated first", %{
      conn: conn,
      source: %{id: source_id}
    } do
      now = DateTime.utc_now()

      for seconds <- [-20, -10, 0] do
        ts = DateTime.add(now, seconds)
        insert(:event, inserted_at: ts, job: build(:job, source_id: source_id, updated_at: ts))
      end

      assert %{"data" => data} =
               response =
               conn
               |> post("/api/v2", %{
                 "query" => @source_with_jobs,
                 "variables" => %{"id" => source_id}
               })
               |> json_response(:ok)

      assert response["errors"] == nil
      assert %{"source" => source} = data
      assert %{"jobs" => jobs} = source
      assert length(jobs) == 3
      assert Enum.sort_by(jobs, & &1["updatedAt"], :desc) == jobs
    end
  end

  describe "sources query" do
    @tag authentication: [role: "user"]
    test "returns forbidden when queried by user role", %{conn: conn} do
      assert %{"data" => data, "errors" => errors} =
               conn
               |> post("/api/v2", %{"query" => @sources_with_events})
               |> json_response(:ok)

      assert data == %{"sources" => nil}
      assert [%{"message" => "forbidden"}] = errors
    end

    @tag authentication: [role: "admin"]
    test "returns events in descending order", %{conn: conn} do
      source_count = 3
      event_limit = 3

      for _ <- 1..source_count, do: insert_job_with_events(5)

      assert %{"data" => data} =
               response =
               conn
               |> post("/api/v2", %{
                 "query" => @sources_with_events,
                 "variables" => %{"eventLimit" => event_limit}
               })
               |> json_response(:ok)

      assert response["errors"] == nil
      assert %{"sources" => sources} = data
      assert length(sources) == source_count

      for %{"events" => events} <- sources do
        assert length(events) == event_limit
        assert Enum.sort(events, &by_id/2) == events
        assert Enum.sort(events, &by_inserted_at/2) == events
      end
    end

    @tag authentication: [role: "admin"]
    test "excludes logically deleted sources", %{conn: conn} do
      expected = Enum.map([1..3], fn _ -> insert(:source) end)
      insert(:source, deleted_at: DateTime.utc_now())

      assert %{"data" => data} =
               response =
               conn
               |> post("/api/v2", %{"query" => @sources})
               |> json_response(:ok)

      assert response["errors"] == nil
      assert %{"sources" => sources} = data
      assert_lists_equal(sources, expected, &(&1["externalId"] == &2.external_id))
    end

    @tag authentication: [role: "admin"]
    test "includes only logically deleted sources if deleted true", %{conn: conn} do
      expected = Enum.map([1..3], fn _ -> insert(:source, deleted_at: DateTime.utc_now()) end)
      insert(:source)

      assert %{"data" => data} =
               response =
               conn
               |> post("/api/v2", %{"query" => @deleted_sources})
               |> json_response(:ok)

      assert response["errors"] == nil
      assert %{"sources" => sources} = data
      assert_lists_equal(sources, expected, &(&1["externalId"] == &2.external_id))
    end
  end

  describe "enableSource mutation" do
    @tag authentication: [role: "user"]
    test "returns forbidden when performed by user role", %{conn: conn} do
      %{id: id} = insert(:source, active: false)

      assert %{"data" => nil, "errors" => errors} =
               conn
               |> post("/api/v2", %{
                 "query" => @enable_source,
                 "variables" => %{"id" => id}
               })
               |> json_response(:ok)

      assert [%{"message" => "forbidden"}] = errors
    end

    @tag authentication: [role: "admin"]
    test "changes active to false when performed by admin role", %{conn: conn} do
      %{id: source_id, external_id: external_id} = insert(:source, active: false)

      assert %{"data" => data} =
               response =
               conn
               |> post("/api/v2", %{
                 "query" => @enable_source,
                 "variables" => %{"id" => source_id}
               })
               |> json_response(:ok)

      assert response["errors"] == nil
      assert %{"enableSource" => source} = data
      assert %{"active" => true, "externalId" => ^external_id} = source
    end
  end

  describe "disableSource mutation" do
    @tag authentication: [role: "user"]
    test "returns forbidden when queried by user role", %{conn: conn} do
      %{id: id} = insert(:source, active: false)

      assert %{"data" => nil, "errors" => errors} =
               conn
               |> post("/api/v2", %{
                 "query" => @disable_source,
                 "variables" => %{"id" => id}
               })
               |> json_response(:ok)

      assert [%{"message" => "forbidden"}] = errors
    end

    @tag authentication: [role: "admin"]
    test "changes active to true when performed by admin role", %{conn: conn} do
      %{id: source_id, external_id: external_id} = insert(:source, active: true)

      assert %{"data" => data} =
               response =
               conn
               |> post("/api/v2", %{
                 "query" => @disable_source,
                 "variables" => %{"id" => source_id}
               })
               |> json_response(:ok)

      assert response["errors"] == nil
      assert %{"disableSource" => source} = data
      assert %{"active" => false, "externalId" => ^external_id} = source
    end
  end

  describe "createSource mutation" do
    setup :create_template

    @tag authentication: [role: "user"]
    test "returns forbidden when queried by user role", %{conn: conn} do
      params = %{"type" => "source_type", "external_id" => "external_id"}

      assert %{"data" => nil, "errors" => errors} =
               conn
               |> post("/api/v2", %{
                 "query" => @create_source,
                 "variables" => %{"source" => params}
               })
               |> json_response(:ok)

      assert [%{"message" => "forbidden"}] = errors
    end

    @tag authentication: [role: "user", permissions: ["manage_raw_quality_rule_implementations"]]
    test "returns forbidden when queried by user role with list permission", %{conn: conn} do
      params = %{"type" => "source_type", "external_id" => "external_id"}

      assert %{"data" => nil, "errors" => errors} =
               conn
               |> post("/api/v2", %{
                 "query" => @create_source,
                 "variables" => %{"source" => params}
               })
               |> json_response(:ok)

      assert [%{"message" => "forbidden"}] = errors
    end

    @tag authentication: [role: "admin"]
    test "creates the source when performed by admin role", %{conn: conn, template: template} do
      params = %{
        "type" => template.name,
        "config" => Jason.encode!(@valid_config),
        "external_id" => "some_external_id"
      }

      assert %{"data" => data} =
               response =
               conn
               |> post("/api/v2", %{
                 "query" => @create_source,
                 "variables" => %{"source" => params}
               })
               |> json_response(:ok)

      assert response["errors"] == nil
      assert %{"createSource" => source} = data
      assert %{"id" => _, "config" => @valid_config} = source
    end
  end

  describe "updateSource mutation" do
    setup :create_template

    @tag authentication: [role: "user"]
    test "returns forbidden for a non-admin user", %{conn: conn} do
      %{id: id} = insert(:source)
      params = %{"id" => id}

      assert %{"data" => nil, "errors" => errors} =
               conn
               |> post("/api/v2", %{
                 "query" => @update_source,
                 "variables" => %{"source" => params}
               })
               |> json_response(:ok)

      assert [%{"message" => "forbidden"}] = errors
    end

    @tag authentication: [role: "admin"]
    test "returns not_found for an admin user", %{conn: conn} do
      params = %{"id" => "123"}

      assert %{"data" => nil, "errors" => errors} =
               conn
               |> post("/api/v2", %{
                 "query" => @update_source,
                 "variables" => %{"source" => params}
               })
               |> json_response(:ok)

      assert [%{"message" => "not_found"}] = errors
    end

    @tag authentication: [role: "admin"]
    test "updates the source for an admin user", %{conn: conn, template: template} do
      %{id: id} = insert(:source, type: template.name)
      params = %{"id" => id, "config" => Jason.encode!(@valid_config)}

      assert %{"data" => data} =
               conn
               |> post("/api/v2", %{
                 "query" => @update_source,
                 "variables" => %{"source" => params}
               })
               |> json_response(:ok)

      assert %{"updateSource" => %{"id" => _, "config" => @valid_config}} = data
    end
  end

  describe "deleteSource mutation" do
    setup do
      start_supervised!(TdCx.Cache.SourcesLatestEvent)
      :ok
    end

    @tag authentication: [role: "user"]
    test "returns forbidden for a non-admin user", %{conn: conn} do
      %{id: id} = insert(:source)

      assert %{"data" => nil, "errors" => errors} =
               conn
               |> post("/api/v2", %{
                 "query" => @delete_source,
                 "variables" => %{"id" => id}
               })
               |> json_response(:ok)

      assert [%{"message" => "forbidden"}] = errors
    end

    @tag authentication: [role: "admin"]
    test "returns not_found for an admin user", %{conn: conn} do
      assert %{"data" => nil, "errors" => errors} =
               conn
               |> post("/api/v2", %{
                 "query" => @delete_source,
                 "variables" => %{"id" => "123"}
               })
               |> json_response(:ok)

      assert [%{"message" => "not_found"}] = errors
    end

    @tag authentication: [role: "admin"]
    test "deletes the source for an admin user", %{conn: conn} do
      %{id: id, external_id: external_id} = insert(:source)

      assert %{"data" => data} =
               conn
               |> post("/api/v2", %{
                 "query" => @delete_source,
                 "variables" => %{"id" => id}
               })
               |> json_response(:ok)

      assert %{"deleteSource" => %{"id" => _, "externalId" => ^external_id}} = data
    end
  end

  defp by_id(%{"id" => id1}, %{"id" => id2}) do
    String.to_integer(id1) > String.to_integer(id2)
  end

  defp by_inserted_at(%{"insertedAt" => dt1}, %{"insertedAt" => dt2}) do
    {:ok, dt1, _} = DateTime.from_iso8601(dt1)
    {:ok, dt2, _} = DateTime.from_iso8601(dt2)
    DateTime.compare(dt1, dt2) == :gt
  end

  defp insert_job_with_events(count) do
    job = insert(:job)
    %{job | events: Enum.map(1..count, fn _ -> insert(:event, job_id: job.id) end)}
  end
end
