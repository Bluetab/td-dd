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
    %{id: user_id, user_name: user_name} = user = CacheHelpers.insert_user()
    %{id: data_structure_id} = data_structure = insert(:data_structure)

    [
      user: user,
      user_id: user_id,
      user_name: user_name,
      claims: build(:claims),
      template: CacheHelpers.insert_template(name: @template_name),
      data_structure: data_structure,
      data_structure_id: data_structure_id
    ]
  end

  describe "get_grant!/1" do
    test "returns the grant with given id" do
      %{id: id} = grant = insert(:grant)
      assert Grants.get_grant!(id) <~> grant
    end

    test "returns the grant preloaded structure" do
      %{id: id} = insert(:grant)

      assert %{data_structure: %{system: %{id: _}}, id: ^id} =
               Grants.get_grant!(id, preload: [data_structure: :system])
    end
  end

  describe "create_grant/3" do
    test "with valid data creates a grant", %{
      claims: claims,
      user_id: user_id,
      user_name: user_name,
      data_structure: data_structure,
      data_structure_id: data_structure_id
    } do
      params = %{
        detail: %{},
        end_date: "2010-04-17",
        start_date: "2010-04-17",
        user_name: user_name
      }

      assert {:ok, %{grant: %Grant{} = grant}} =
               Grants.create_grant(params, data_structure, claims)

      assert %{
               detail: %{},
               end_date: ~D[2010-04-17],
               start_date: ~D[2010-04-17],
               user_id: ^user_id,
               data_structure_id: ^data_structure_id
             } = grant
    end

    test "publishes an audit event", %{
      claims: claims,
      user_id: user_id,
      data_structure: data_structure
    } do
      params = %{
        detail: %{},
        end_date: "2010-04-17",
        start_date: "2010-04-17",
        user_id: user_id
      }

      assert {:ok, %{audit: event_id, grant: grant}} =
               Grants.create_grant(params, data_structure, claims)

      assert {:ok, [event]} = Stream.range(:redix, @stream, event_id, event_id, transform: :range)

      assert %{
               event: "grant_created",
               id: ^event_id,
               payload: payload,
               resource_id: resource_id,
               resource_type: "grant",
               user_id: audit_user_id
             } = event

      assert resource_id == to_string(grant.id)
      assert audit_user_id == to_string(claims.user_id)

      assert %{
               "detail" => %{},
               "end_date" => "2010-04-17",
               "start_date" => "2010-04-17",
               "user_id" => ^user_id
             } = Jason.decode!(payload)
    end

    test "will not allow a start date to be greater than the end_date", %{
      claims: claims,
      data_structure: data_structure,
      user_id: user_id
    } do
      params = %{
        end_date: "2010-04-10",
        start_date: "2010-04-20",
        user_id: user_id
      }

      assert {:error, :grant, %{errors: errors}, _} =
               Grants.create_grant(params, data_structure, claims)

      assert {_, [constraint: :check, constraint_name: "date_range"]} = errors[:end_date]
    end

    test "will not allow two grants of same structure and user on the same period",
         %{user_id: user_id, data_structure: data_structure, claims: claims} do
      params = %{
        end_date: "2010-04-20",
        start_date: "2010-04-16",
        user_id: user_id
      }

      assert {:ok, _} = Grants.create_grant(params, data_structure, claims)

      params = %{
        start_date: "2010-04-18",
        user_id: user_id
      }

      assert {:error, :grant, %{errors: errors}, _} =
               Grants.create_grant(params, data_structure, claims)

      assert {_, [{:constraint, :exclusion}, {:constraint_name, "no_overlap"}]} = errors[:user_id]

      params = %{
        start_date: "2010-04-15",
        end_date: "2010-04-19",
        user_id: user_id
      }

      assert {:error, :grant, %{errors: errors}, _} =
               Grants.create_grant(params, data_structure, claims)

      assert {_, [{:constraint, :exclusion}, {:constraint_name, "no_overlap"}]} = errors[:user_id]
    end

    test "will allow two grants of same structure and user on different periods",
         %{claims: claims, data_structure: data_structure, user_id: user_id} do
      params = %{
        end_date: "2010-04-20",
        start_date: "2010-04-16",
        user_id: user_id
      }

      assert {:ok, _} = Grants.create_grant(params, data_structure, claims)

      params = %{
        start_date: "2010-04-21",
        end_date: "2010-04-26",
        user_id: user_id
      }

      assert {:ok, _} = Grants.create_grant(params, data_structure, claims)
    end

    test "with invalid data returns error changeset", %{
      claims: claims,
      data_structure: data_structure
    } do
      invalid_params = %{start_date: nil, user_id: nil}

      assert {:error, :grant, %{errors: errors}, _} =
               Grants.create_grant(invalid_params, data_structure, claims)

      assert {_, [validation: :required]} = errors[:user_id]
      assert {_, [validation: :required]} = errors[:start_date]
    end
  end

  describe "update_grant/3" do
    test "with valid data updates the grant", %{claims: claims} do
      grant = insert(:grant)

      params = %{
        detail: %{},
        end_date: "2011-05-18",
        start_date: "2011-05-18"
      }

      assert {:ok, %{grant: grant}} = Grants.update_grant(grant, params, claims)

      assert %{
               detail: detail,
               end_date: ~D[2011-05-18],
               start_date: ~D[2011-05-18]
             } = grant

      assert detail == %{}
    end

    test "does not change user_id", %{claims: claims, user_id: new_user_id} do
      %{user_id: user_id} = grant = insert(:grant)
      params = %{user_id: new_user_id}
      assert new_user_id != user_id
      assert {:ok, %{grant: grant}} = Grants.update_grant(grant, params, claims)
      assert %{user_id: ^user_id} = grant
    end

    test "publishes an audit event", %{claims: claims, user_id: user_id} do
      %{id: id} = grant = insert(:grant)

      params = %{
        detail: %{},
        end_date: "2011-05-18",
        start_date: "2011-05-18",
        user_id: user_id
      }

      assert {:ok, %{audit: event_id}} = Grants.update_grant(grant, params, claims)
      assert {:ok, [event]} = Stream.range(:redix, @stream, event_id, event_id, transform: :range)

      assert %{
               event: "grant_updated",
               id: ^event_id,
               payload: payload,
               resource_id: resource_id,
               resource_type: "grant",
               user_id: audit_user_id
             } = event

      assert audit_user_id == to_string(claims.user_id)
      assert resource_id == to_string(id)

      assert Jason.decode!(payload) == %{
               "detail" => %{},
               "end_date" => "2011-05-18",
               "start_date" => "2011-05-18"
             }
    end

    test "with invalid data returns error changeset", %{claims: claims} do
      grant = insert(:grant)

      invalid_params = %{start_date: nil, user_id: nil}

      assert {:error, :grant, %{errors: errors}, _} =
               Grants.update_grant(grant, invalid_params, claims)

      assert {_, [validation: :required]} = errors[:start_date]
    end
  end

  describe "delete_grant/1" do
    test "deletes the grant", %{claims: claims} do
      %{id: id} = grant = insert(:grant)

      assert {:ok, %{grant: %Grant{}}} = Grants.delete_grant(grant, claims)

      assert_raise Ecto.NoResultsError, fn -> Grants.get_grant!(id) end
    end

    test "publishes an audit event", %{
      claims: claims
    } do
      %{id: id, data_structure_id: data_structure_id, user_id: user_id} = grant = insert(:grant)

      assert {:ok, %{audit: event_id}} = Grants.delete_grant(grant, claims)
      assert {:ok, [event]} = Stream.range(:redix, @stream, event_id, event_id, transform: :range)

      assert %{
               event: "grant_deleted",
               id: ^event_id,
               payload: payload,
               resource_id: resource_id,
               resource_type: "grant",
               user_id: audit_user_id
             } = event

      assert audit_user_id == to_string(claims.user_id)
      assert resource_id == to_string(id)

      assert %{
               "data_structure_id" => ^data_structure_id,
               "domain_ids" => [],
               "end_date" => "2021-02-03",
               "resource" => %{},
               "start_date" => "2020-01-02",
               "user_id" => ^user_id
             } = Jason.decode!(payload)
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
