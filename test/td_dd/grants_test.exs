defmodule TdDd.GrantsTest do
  use TdDd.DataCase
  import TdDd.TestOperators

  alias TdCache.Redix
  alias TdCache.Redix.Stream
  alias TdDd.Grants

  @stream TdCache.Audit.stream()

  setup_all do
    on_exit(fn -> Redix.del!(@stream) end)
  end

  describe "grants" do
    alias TdDd.Grants.Grant

    @valid_attrs %{
      detail: %{},
      end_date: "2010-04-17T14:00:00.000000Z",
      start_date: "2010-04-17T14:00:00.000000Z",
      user_id: 42
    }
    @update_attrs %{
      detail: %{},
      end_date: "2011-05-18T15:01:01.000000Z",
      start_date: "2011-05-18T15:01:01.000000Z",
      user_id: 43
    }
    @invalid_attrs %{detail: nil, end_date: nil, start_date: nil, user_id: nil}

    test "list_grants/0 returns all grants" do
      grant = insert(:grant)
      assert Grants.list_grants() <|> [grant]
    end

    test "get_grant!/1 returns the grant with given id" do
      grant = insert(:grant)
      assert Grants.get_grant!(grant.id) <~> grant
    end

    test "get_grant!/1 returns the grant preloaded structure" do
      grant = insert(:grant)
      refute Grants.get_grant!(grant.id) == grant
      assert Grants.get_grant!(grant.id, preload: [data_structure: [:system]]) == grant
    end

    test "create_grant/3 with valid data creates a grant" do
      claims = build(:claims)
      %{id: data_structure_id} = data_structure = insert(:data_structure)

      assert {:ok,
              %{
                audit: event_id,
                grant: %Grant{} = grant
              }} = Grants.create_grant(@valid_attrs, data_structure, claims)

      date_value = DateTime.from_naive!(~N[2010-04-17T14:00:00.000000Z], "Etc/UTC")
      assert grant.detail == %{}
      assert grant.end_date == date_value
      assert grant.start_date == date_value
      assert grant.user_id == 42
      assert grant.data_structure_id == data_structure_id

      assert {:ok, [%{id: ^event_id, payload: payload}]} =
               Stream.range(:redix, @stream, event_id, event_id, transform: :range)

      date_string_value = Map.get(@valid_attrs, :end_date)

      assert %{
               "detail" => %{},
               "end_date" => ^date_string_value,
               "start_date" => ^date_string_value,
               "user_id" => 42,
               "data_structure_id" => ^data_structure_id
             } = Jason.decode!(payload)
    end

    test "create_grant/3 will not allow a start date to be greater than the end_date" do
      claims = build(:claims)
      data_structure = insert(:data_structure)

      attrs = %{
        end_date: "2010-04-10T00:00:00.000000Z",
        start_date: "2010-04-20T00:00:00.000000Z",
        user_id: 42
      }

      assert {:error, :grant, %Ecto.Changeset{}, _} =
               Grants.create_grant(attrs, data_structure, claims)
    end

    test "create_grant/3 will not allow two grants of same structure and user on the same period" do
      claims = build(:claims)
      data_structure = insert(:data_structure)

      attrs = %{
        end_date: "2010-04-20T00:00:00.000000Z",
        start_date: "2010-04-16T00:00:00.000000Z",
        user_id: 42
      }

      assert {:ok, _} = Grants.create_grant(attrs, data_structure, claims)

      attrs = %{
        start_date: "2010-04-18T00:00:00.000000Z",
        user_id: 42
      }

      assert {:error, :overlap, %Ecto.Changeset{} = error, _} =
               Grants.create_grant(attrs, data_structure, claims)

      assert %{errors: [date_range: {"overlaps", []}]} = error

      attrs = %{
        start_date: "2010-04-15T00:00:00.000000Z",
        end_date: "2010-04-19T00:00:00.000000Z",
        user_id: 42
      }

      assert {:error, :overlap, %Ecto.Changeset{} = error, _} =
               Grants.create_grant(attrs, data_structure, claims)

      assert %{errors: [date_range: {"overlaps", []}]} = error
    end

    test "create_grant/3 will allow two grants of same structure and user on different periods" do
      claims = build(:claims)
      data_structure = insert(:data_structure)

      attrs = %{
        end_date: "2010-04-20T00:00:00.000000Z",
        start_date: "2010-04-16T00:00:00.000000Z",
        user_id: 42
      }

      assert {:ok, _} = Grants.create_grant(attrs, data_structure, claims)

      attrs = %{
        start_date: "2010-04-21T00:00:00.000000Z",
        end_date: "2010-04-26T00:00:00.000000Z",
        user_id: 42
      }

      assert {:ok, _} = Grants.create_grant(attrs, data_structure, claims)
    end

    test "create_grant/3 with invalid data returns error changeset" do
      claims = build(:claims)
      data_structure = insert(:data_structure)

      assert {:error, :grant, %Ecto.Changeset{}, _} =
               Grants.create_grant(@invalid_attrs, data_structure, claims)
    end

    test "update_grant/2 with valid data updates the grant" do
      claims = build(:claims)
      %{user_id: previous_user_id} = grant = insert(:grant)

      assert {:ok,
              %{
                audit: event_id,
                grant: %Grant{} = grant
              }} = Grants.update_grant(grant, @update_attrs, claims)

      assert grant.detail == %{}
      assert grant.end_date == DateTime.from_naive!(~N[2011-05-18T15:01:01.000000Z], "Etc/UTC")
      assert grant.start_date == DateTime.from_naive!(~N[2011-05-18T15:01:01.000000Z], "Etc/UTC")
      assert grant.user_id == previous_user_id

      assert {:ok, [%{id: ^event_id, payload: payload}]} =
               Stream.range(:redix, @stream, event_id, event_id, transform: :range)

      date_string_value = Map.get(@update_attrs, :end_date)

      assert %{
               "detail" => %{},
               "end_date" => ^date_string_value,
               "start_date" => ^date_string_value
             } = Jason.decode!(payload)
    end

    test "update_grant/2 with invalid data returns error changeset" do
      claims = build(:claims)
      grant = insert(:grant)

      assert {:error, :grant, %Ecto.Changeset{}, _} =
               Grants.update_grant(grant, @invalid_attrs, claims)

      assert grant <~> Grants.get_grant!(grant.id)
    end

    test "delete_grant/1 deletes the grant" do
      claims = build(:claims)
      grant = insert(:grant)

      assert {:ok,
              %{
                audit: event_id,
                grant: %Grant{}
              }} = Grants.delete_grant(grant, claims)

      assert {:ok, [%{id: ^event_id, payload: "{}"}]} =
               Stream.range(:redix, @stream, event_id, event_id, transform: :range)

      assert_raise Ecto.NoResultsError, fn -> Grants.get_grant!(grant.id) end
    end
  end

  describe "grant_request_groups" do
    alias TdDd.Grants.GrantRequest
    alias TdDd.Grants.GrantRequestGroup

    @valid_attrs %{request_date: "2010-04-17T14:00:00.000000Z", type: "some type", user_id: 42}
    @update_attrs %{
      request_date: "2011-05-18T15:01:01.000000Z",
      type: "some updated type",
      user_id: 43
    }
    @invalid_attrs %{request_date: nil, type: nil, user_id: nil}

    test "list_grant_request_groups/0 returns all grant_request_groups" do
      grant_request_group = insert(:grant_request_group)
      assert Grants.list_grant_request_groups() <|> [grant_request_group]
    end

    test "get_grant_request_group!/1 returns the grant_request_group with given id" do
      grant_request_group = insert(:grant_request_group)
      assert Grants.get_grant_request_group!(grant_request_group.id) <~> grant_request_group
    end

    test "create_grant_request_group/1 with valid data creates a grant_request_group" do
      assert {:ok, %GrantRequestGroup{} = grant_request_group} =
               Grants.create_grant_request_group(@valid_attrs)

      assert grant_request_group.request_date ==
               DateTime.from_naive!(~N[2010-04-17T14:00:00.000000Z], "Etc/UTC")

      assert grant_request_group.type == "some type"
      assert grant_request_group.user_id == 42
    end

    test "creates grant_request_group child requests" do
      %{id: ds_id_1} = insert(:data_structure)
      %{id: ds_id_2} = insert(:data_structure)

      requests = [
        %{
          data_structure_id: ds_id_1,
          filters: %{"foo" => "bar"},
          metadata: %{"bar" => "foo"}
        },
        %{data_structure_id: ds_id_2}
      ]

      attrs = Map.put(@valid_attrs, :requests, requests)

      assert {:ok, %GrantRequestGroup{id: id}} = Grants.create_grant_request_group(attrs)

      assert [
               %{
                 data_structure_id: ^ds_id_1,
                 filters: %{"foo" => "bar"},
                 metadata: %{"bar" => "foo"}
               },
               %{data_structure_id: ^ds_id_2}
             ] = Grants.list_grant_requests(id)
    end

    test "create_grant_request_group/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Grants.create_grant_request_group(@invalid_attrs)
    end

    test "update_grant_request_group/2 with valid data updates the grant_request_group" do
      %{user_id: user_id} = grant_request_group = insert(:grant_request_group)

      assert {:ok, %GrantRequestGroup{} = grant_request_group} =
               Grants.update_grant_request_group(grant_request_group, @update_attrs)

      assert grant_request_group.request_date ==
               DateTime.from_naive!(~N[2011-05-18T15:01:01.000000Z], "Etc/UTC")

      assert grant_request_group.type == "some updated type"
      assert grant_request_group.user_id == user_id
    end

    test "update_grant_request_group/2 with invalid data returns error changeset" do
      grant_request_group = insert(:grant_request_group)

      assert {:error, %Ecto.Changeset{}} =
               Grants.update_grant_request_group(grant_request_group, @invalid_attrs)

      assert grant_request_group <~> Grants.get_grant_request_group!(grant_request_group.id)
    end

    test "delete_grant_request_group/1 deletes the grant_request_group" do
      grant_request_group = insert(:grant_request_group)
      assert {:ok, %GrantRequestGroup{}} = Grants.delete_grant_request_group(grant_request_group)

      assert_raise Ecto.NoResultsError, fn ->
        Grants.get_grant_request_group!(grant_request_group.id)
      end
    end
  end

  describe "grant_requests" do
    alias TdCache.TemplateCache
    alias TdDd.Grants.GrantRequest

    @valid_attrs %{filters: %{"foo" => "bar"}, metadata: %{"foo" => "bar"}}
    @update_attrs %{filters: %{}, metadata: %{}}

    @template_name "grant_request_test_template"

    setup _ do
      %{id: template_id} = template = build(:template, name: @template_name)
      {:ok, _} = TemplateCache.put(template, publish: false)
      on_exit(fn -> TemplateCache.delete(template_id) end)
    end

    test "list_grant_requests/0 returns all grant_requests" do
      _other_group_request = insert(:grant_request)
      %{grant_request_group_id: grant_request_group_id} = grant_request = insert(:grant_request)
      assert Grants.list_grant_requests(grant_request_group_id) <|> [grant_request]
    end

    test "get_grant_request!/1 returns the grant_request with given id" do
      grant_request = insert(:grant_request)
      assert Grants.get_grant_request!(grant_request.id) <~> grant_request
    end

    test "create_grant_request/1 with valid data creates a grant_request" do
      grant_request_group = insert(:grant_request_group, type: @template_name)
      data_structure = insert(:data_structure)

      metadata = %{
        "list" => "one",
        "string" => "bar"
      }

      attrs = Map.put(@valid_attrs, :metadata, metadata)

      assert {:ok, %GrantRequest{} = grant_request} =
               Grants.create_grant_request(attrs, grant_request_group, data_structure)

      assert grant_request.filters == %{"foo" => "bar"}
      assert grant_request.metadata == metadata
    end

    test "create_grant_request/1 fails if metadata is invalid" do
      grant_request_group = insert(:grant_request_group, type: @template_name)
      data_structure = insert(:data_structure)

      attrs = Map.put(@valid_attrs, :metadata, %{"invalid" => "metadata"})

      assert {:error,
              %{
                errors: [
                  metadata:
                    {"invalid content",
                     [
                       list: {"can't be blank", [validation: :required]},
                       string: {"can't be blank", [validation: :required]}
                     ]}
                ]
              }} = Grants.create_grant_request(attrs, grant_request_group, data_structure)
    end

    test "update_grant_request/2 with valid data updates the grant_request" do
      grant_request = insert(:grant_request)

      assert {:ok, %GrantRequest{} = grant_request} =
               Grants.update_grant_request(grant_request, @update_attrs)

      assert grant_request.filters == %{}
      assert grant_request.metadata == %{}
    end

    test "delete_grant_request/1 deletes the grant_request" do
      grant_request = insert(:grant_request)
      assert {:ok, %GrantRequest{}} = Grants.delete_grant_request(grant_request)
      assert_raise Ecto.NoResultsError, fn -> Grants.get_grant_request!(grant_request.id) end
    end
  end
end
