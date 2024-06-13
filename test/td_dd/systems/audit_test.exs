defmodule TdDd.Systems.AuditTest do
  use TdDd.DataCase

  alias TdCache.Redix
  alias TdCache.Redix.Stream
  alias TdDd.Repo
  alias TdDd.Systems.Audit
  alias TdDd.Systems.System

  @stream TdCache.Audit.stream()

  setup_all do
    Redix.del!(@stream)
    :ok
  end

  setup do
    on_exit(fn -> Redix.del!(@stream) end)

    CacheHelpers.insert_template(name: System._test_get_template_name())
    claims = build(:claims, role: "admin")
    [claims: claims, system: insert(:system)]
  end

  describe "system_created/4" do
    test "publishes an event", %{system: %{id: system_id} = system, claims: %{user_id: user_id}} do
      content = %{foo: %{"value" => "bar", "origin" => "user"}}

      %{external_id: external_id, name: name} =
        params =
        build(:system)
        |> Map.take([:external_id, :name])
        |> Map.put(:df_content, content)

      changeset = System.changeset(params)
      assert {:ok, event_id} = Audit.system_created(Repo, %{system: system}, changeset, user_id)
      assert {:ok, [event]} = Stream.range(:redix, @stream, event_id, event_id, transform: :range)

      user_id = "#{user_id}"
      resource_id = "#{system_id}"

      assert %{
               event: "system_created",
               payload: payload,
               resource_id: ^resource_id,
               resource_type: "system",
               service: "td_dd",
               ts: _ts,
               user_id: ^user_id
             } = event

      assert %{
               "content" => _content,
               "external_id" => ^external_id,
               "name" => ^name
             } = Jason.decode!(payload)
    end
  end

  describe "system_updated/4" do
    test "publishes an event", %{claims: %{user_id: user_id}} do
      content = %{foo: "bar"}

      %{id: system_id} = system = insert(:system, df_content: content)

      %{name: name} =
        params =
        build(:system)
        |> Map.take([:name])
        |> Map.put(:df_content, %{bar: %{"value" => "bar", "origin" => "user"}})

      changeset = System.changeset(params)
      assert {:ok, event_id} = Audit.system_updated(Repo, %{system: system}, changeset, user_id)
      assert {:ok, [event]} = Stream.range(:redix, @stream, event_id, event_id, transform: :range)

      user_id = "#{user_id}"
      resource_id = "#{system_id}"

      assert %{
               event: "system_updated",
               payload: payload,
               resource_id: ^resource_id,
               resource_type: "system",
               service: "td_dd",
               ts: _ts,
               user_id: ^user_id
             } = event

      assert %{
               "content" => _content,
               "name" => ^name
             } = Jason.decode!(payload)
    end
  end

  describe "system_deleted/3" do
    test "publishes an event", %{claims: %{user_id: user_id}} do
      %{id: system_id} = system = insert(:system)

      assert {:ok, event_id} = Audit.system_deleted(Repo, %{system: system}, user_id)
      assert {:ok, [event]} = Stream.range(:redix, @stream, event_id, event_id, transform: :range)

      user_id = "#{user_id}"
      resource_id = "#{system_id}"

      assert %{
               event: "system_deleted",
               payload: "{}",
               resource_id: ^resource_id,
               resource_type: "system",
               service: "td_dd",
               ts: _ts,
               user_id: ^user_id
             } = event
    end
  end
end
