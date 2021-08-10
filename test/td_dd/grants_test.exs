defmodule TdDd.GrantsTest do
  use TdDd.DataCase

  import TdDd.TestOperators

  alias TdCache.Redix
  alias TdCache.Redix.Stream
  alias TdDd.Grants
  alias TdDd.Grants.Grant
  alias TdDd.Grants.GrantRequest
  alias TdDd.Grants.GrantRequestGroup

  @stream TdCache.Audit.stream()
  @template_name "grant_request_test_template"
  @valid_metadata %{"list" => "one", "string" => "bar"}

  setup_all do
    on_exit(fn -> Redix.del!(@stream) end)
  end

  setup do
    [template: CacheHelpers.insert_template(name: @template_name)]
  end

  describe "grants" do
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
      %{user_id: user_id} = claims = build(:claims)
      %{id: data_structure_id} = data_structure = insert(:data_structure)

      params = %{
        detail: %{},
        end_date: "2010-04-17T14:00:00.000000Z",
        start_date: "2010-04-17T14:00:00.000000Z"
      }

      assert {:ok,
              %{
                audit: event_id,
                grant: %Grant{} = grant
              }} = Grants.create_grant(params, data_structure, claims)

      assert %{
               detail: %{},
               end_date: ~U[2010-04-17T14:00:00.000000Z],
               start_date: ~U[2010-04-17T14:00:00.000000Z],
               user_id: ^user_id,
               data_structure_id: ^data_structure_id
             } = grant

      assert {:ok, [%{id: ^event_id, payload: payload, user_id: audit_user_id}]} =
               Stream.range(:redix, @stream, event_id, event_id, transform: :range)

      assert audit_user_id == to_string(user_id)

      assert %{
               "detail" => %{},
               "end_date" => "2010-04-17T14:00:00.000000Z",
               "start_date" => "2010-04-17T14:00:00.000000Z"
             } = Jason.decode!(payload)
    end

    test "create_grant/3 will not allow a start date to be greater than the end_date" do
      claims = build(:claims)
      data_structure = insert(:data_structure)

      params = %{
        end_date: "2010-04-10T00:00:00.000000Z",
        start_date: "2010-04-20T00:00:00.000000Z"
      }

      assert {:error, :grant, %Ecto.Changeset{}, _} =
               Grants.create_grant(params, data_structure, claims)
    end

    test "create_grant/3 will not allow two grants of same structure and user on the same period" do
      claims = build(:claims)
      data_structure = insert(:data_structure)

      params = %{
        end_date: "2010-04-20T00:00:00.000000Z",
        start_date: "2010-04-16T00:00:00.000000Z"
      }

      assert {:ok, _} = Grants.create_grant(params, data_structure, claims)

      params = %{
        start_date: "2010-04-18T00:00:00.000000Z"
      }

      assert {:error, :overlap, %Ecto.Changeset{} = error, _} =
               Grants.create_grant(params, data_structure, claims)

      assert %{errors: [date_range: {"overlaps", []}]} = error

      params = %{
        start_date: "2010-04-15T00:00:00.000000Z",
        end_date: "2010-04-19T00:00:00.000000Z"
      }

      assert {:error, :overlap, %Ecto.Changeset{} = error, _} =
               Grants.create_grant(params, data_structure, claims)

      assert %{errors: [date_range: {"overlaps", []}]} = error
    end

    test "create_grant/3 will allow two grants of same structure and user on different periods" do
      claims = build(:claims)
      data_structure = insert(:data_structure)

      params = %{
        end_date: "2010-04-20T00:00:00.000000Z",
        start_date: "2010-04-16T00:00:00.000000Z"
      }

      assert {:ok, _} = Grants.create_grant(params, data_structure, claims)

      params = %{
        start_date: "2010-04-21T00:00:00.000000Z",
        end_date: "2010-04-26T00:00:00.000000Z"
      }

      assert {:ok, _} = Grants.create_grant(params, data_structure, claims)
    end

    test "create_grant/3 with invalid data returns error changeset" do
      claims = build(:claims)
      data_structure = insert(:data_structure)
      invalid_params = %{detail: nil, end_date: nil, start_date: nil, user_id: nil}

      assert {:error, :grant, %Ecto.Changeset{}, _} =
               Grants.create_grant(invalid_params, data_structure, claims)
    end

    test "update_grant/3 with valid data updates the grant" do
      claims = build(:claims)
      %{user_id: previous_user_id} = grant = insert(:grant)

      params = %{
        detail: %{},
        end_date: "2011-05-18T15:01:01.000000Z",
        start_date: "2011-05-18T15:01:01.000000Z",
        user_id: 43
      }

      assert {:ok, %{audit: event_id, grant: grant}} = Grants.update_grant(grant, params, claims)

      assert %{
               detail: %{},
               end_date: ~U[2011-05-18T15:01:01.000000Z],
               start_date: ~U[2011-05-18T15:01:01.000000Z],
               user_id: ^previous_user_id
             } = grant

      assert {:ok, [%{id: ^event_id, payload: payload}]} =
               Stream.range(:redix, @stream, event_id, event_id, transform: :range)

      assert %{
               "detail" => %{},
               "end_date" => "2011-05-18T15:01:01.000000Z",
               "start_date" => "2011-05-18T15:01:01.000000Z"
             } = Jason.decode!(payload)
    end

    test "update_grant/3 with invalid data returns error changeset" do
      claims = build(:claims)
      grant = insert(:grant)

      invalid_params = %{detail: nil, end_date: nil, start_date: nil, user_id: nil}

      assert {:error, :grant, %Ecto.Changeset{}, _} =
               Grants.update_grant(grant, invalid_params, claims)

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
    test "list_grant_request_groups/0 returns all grant_request_groups" do
      grant_request_group = insert(:grant_request_group)
      assert Grants.list_grant_request_groups() <|> [grant_request_group]
    end

    test "get_grant_request_group!/1 returns the grant_request_group with given id" do
      grant_request_group = insert(:grant_request_group)
      assert Grants.get_grant_request_group!(grant_request_group.id) <~> grant_request_group
    end

    test "create_grant_request_group/2 with valid data creates a grant_request_group" do
      %{id: data_structure_id} = insert(:data_structure)
      %{user_id: user_id} = claims = build(:claims)

      params = %{
        type: @template_name,
        requests: [%{data_structure_id: data_structure_id, metadata: @valid_metadata}]
      }

      assert {:ok, %GrantRequestGroup{} = grant_request_group} =
               Grants.create_grant_request_group(params, claims)

      assert %{
               type: @template_name,
               user_id: ^user_id
             } = grant_request_group
    end

    test "creates grant_request_group child requests" do
      %{id: ds_id_1} = insert(:data_structure)
      %{id: ds_id_2} = insert(:data_structure)

      requests = [
        %{
          data_structure_id: ds_id_1,
          filters: %{"foo" => "bar"},
          metadata: @valid_metadata
        },
        %{data_structure_id: ds_id_2, metadata: @valid_metadata}
      ]

      params = %{
        type: @template_name,
        requests: requests
      }

      assert {:ok, %GrantRequestGroup{id: id}} =
               Grants.create_grant_request_group(params, build(:claims))

      assert [
               %{
                 data_structure_id: ^ds_id_1,
                 filters: %{"foo" => "bar"},
                 metadata: @valid_metadata
               },
               %{data_structure_id: ^ds_id_2}
             ] = Grants.list_grant_requests(id)
    end

    test "create_grant_request_group/1 with invalid data returns error changeset" do
      invalid_params = %{type: nil}

      assert {:error, %Ecto.Changeset{}} =
               Grants.create_grant_request_group(invalid_params, build(:claims))
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

      filters = %{"foo" => "bar"}
      metadata = @valid_metadata
      params = %{"filters" => filters, "metadata" => metadata}

      assert {:ok, %GrantRequest{} = grant_request} =
               Grants.create_grant_request(params, grant_request_group, data_structure)

      assert %{filters: ^filters, metadata: ^metadata} = grant_request
    end

    test "create_grant_request/1 fails if metadata is invalid" do
      grant_request_group = insert(:grant_request_group, type: @template_name)
      data_structure = insert(:data_structure)

      params = %{"filters" => %{"foo" => "bar"}, "metadata" => %{"invalid" => "metadata"}}

      assert {:error, %{errors: errors}} =
               Grants.create_grant_request(params, grant_request_group, data_structure)

      assert {_,
              [
                list: {_, [validation: :required]},
                string: {_, [validation: :required]}
              ]} = errors[:metadata]
    end

    test "update_grant_request/2 with valid data updates the grant_request" do
      grant_request = insert(:grant_request)

      params = %{"filters" => %{}, "metadata" => %{}}

      assert {:ok, %GrantRequest{} = grant_request} =
               Grants.update_grant_request(grant_request, params)

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
