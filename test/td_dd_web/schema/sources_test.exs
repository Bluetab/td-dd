defmodule TdDdWeb.Schema.SourcesTest do
  use TdDdWeb.ConnCase

  @source_with_template """
  query SOURCE($id: ID!) {
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

  @sources_with_events """
  query SOURCES($eventLimit: Int) {
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

  @sources_with_events_not_deleted """
  query SOURCES($eventLimit: Int) {
    sources(include_deleted: false) {
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
  mutation ENABLE_SOURCE($id: ID!) {
    enableSource(id: $id) {
      id
      externalId
      active
    }
  }
  """

  @disable_source """
  mutation DISABLE_SOURCE($id: ID!) {
    disableSource(id: $id) {
      id
      externalId
      active
    }
  }
  """

  defp create_template(%{domain: domain_name}) do
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

  defp create_source(%{template: %{name: source_type}} = context) do
    domain_id = context[:domain][:id]
    config = %{"foo" => "bar", "domain" => %{"id" => domain_id}}
    [source: insert(:source, config: config, type: source_type)]
  end

  describe "source query" do
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
    test "enriches domain configuration from cache", %{conn: conn, source: %{id: source_id}} do
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
      assert %{"name" => "foo", "external_id" => _} = config["domain"]
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
  end

  describe "enableSource mutation" do
    @tag authentication: [role: "user"]
    test "returns forbidden when performed by user role", %{conn: conn} do
      assert %{"data" => nil, "errors" => errors} =
               conn
               |> post("/api/v2", %{
                 "query" => @enable_source,
                 "variables" => %{"id" => 123}
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

    @tag authentication: [role: "admin"]
    test "deleted: false excludes logically deleted sources (not nil deleted_at)", %{conn: conn} do
      event_limit = 3

      %{id: source_not_deleted_id} = _source_not_deleted = insert(:source)
      _source_deleted = insert(:source, deleted_at: DateTime.now!("Etc/UTC"))

      assert %{"data" => %{ "sources" => sources}} =
        response =
        conn
        |> post("/api/v2", %{
          "query" => @sources_with_events_not_deleted,
          "variables" => %{
            "eventLimit" => event_limit,
            "deleted" => false
          }
        })
        |> json_response(:ok)

      assert response["errors"] == nil
      assert Integer.to_string(source_not_deleted_id) == Enum.at(sources, 0)["id"]
    end
  end

  describe "disableSource mutation" do
    @tag authentication: [role: "user"]
    test "returns forbidden when queried by user role", %{conn: conn} do
      assert %{"data" => nil, "errors" => errors} =
               conn
               |> post("/api/v2", %{
                 "query" => @disable_source,
                 "variables" => %{"id" => 123}
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
