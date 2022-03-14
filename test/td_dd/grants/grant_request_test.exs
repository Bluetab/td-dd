defmodule TdDd.Grants.GrantRequestTest do
  use TdDd.DataCase

  use Ecto.Schema

  alias Ecto.Changeset
  alias TdDd.Grants.GrantRequest

  setup do
    identifier_name = "identifier"

    with_identifier = %{
      id: System.unique_integer([:positive]),
      name: "template_grant_request_with_identifier",
      label: "template_grant_request_with_identifier",
      scope: "gr",
      content: [
        %{
          "fields" => [
            %{
              "cardinality" => "1",
              "default" => "",
              "label" => "Identifier",
              "name" => identifier_name,
              "subscribable" => false,
              "type" => "string",
              "values" => nil,
              "widget" => "identifier"
            },
            %{
              "cardinality" => "1",
              "default" => "",
              "label" => "Text",
              "name" => "text",
              "subscribable" => false,
              "type" => "string",
              "values" => nil,
              "widget" => "text"
            }
          ],
          "name" => ""
        }
      ]
    }

    without_identifier = %{
      id: System.unique_integer([:positive]),
      name: "template_grant_request_without_identifier",
      label: "template_grant_request_without_identifier",
      scope: "gr",
      content: [
        %{
          "fields" => [
            %{
              "cardinality" => "1",
              "default" => "",
              "label" => "Text",
              "name" => "text",
              "subscribable" => false,
              "type" => "string",
              "values" => nil,
              "widget" => "text"
            }
          ],
          "name" => ""
        }
      ]
    }

    template_with_identifier = CacheHelpers.insert_template(with_identifier)
    template_without_identifier = CacheHelpers.insert_template(without_identifier)

    [
      template_with_identifier: template_with_identifier,
      template_without_identifier: template_without_identifier,
      identifier_name: identifier_name
    ]
  end

  describe "changeset/3" do
    test "create new grant request: puts a new identifier if the template has an identifier field",
         %{
           template_with_identifier: template_with_identifier,
           identifier_name: identifier_name
         } do
      # %{id: domain_id} = CacheHelpers.insert_domain()
      # %{user_id: user_id} = claims = build(:claims, role: "user")

      params = %{
        group: build(:grant_request_group, user_id: 1),
        data_structure: build(:data_structure),
        metadata: %{"text" => "some text"}
      }

      assert %Changeset{changes: changes} =
               GrantRequest.changeset(%GrantRequest{}, params, template_with_identifier.name)

      assert %{metadata: new_content} = changes
      assert %{^identifier_name => _identifier} = new_content
    end

    test "create new grant request: avoids putting new identifier if template lacks an identifier field",
         %{
           template_without_identifier: template_without_identifier,
           identifier_name: identifier_name
         } do
      # %{id: domain_id} = CacheHelpers.insert_domain()
      # %{user_id: user_id} = claims = build(:claims, role: "user")

      params = %{
        group: build(:grant_request_group, user_id: 1),
        data_structure: build(:data_structure),
        metadata: %{"text" => "some text"}
      }

      assert %Changeset{changes: changes} =
               GrantRequest.changeset(%GrantRequest{}, params, template_without_identifier.name)

      assert %{metadata: new_content} = changes
      refute match?(%{^identifier_name => _identifier}, new_content)
    end

    test "keeps an already present identifier (i.e., editing)", %{
      template_with_identifier: template_with_identifier,
      identifier_name: identifier_name
    } do
      # Existing identifier previously put by the create changeset
      existing_identifier = "00000000-0000-0000-0000-000000000000"

      grant_request = %GrantRequest{
        filters: %{"grant_filters" => "bar"},
        metadata: %{"old" => "foo", identifier_name => existing_identifier},
        domain_ids: [123]
      }

      params = %{
        group: build(:grant_request_group, user_id: 1),
        data_structure: build(:data_structure),
        metadata: %{"text" => "some text"}
      }

      assert %Changeset{changes: changes} =
               GrantRequest.changeset(grant_request, params, template_with_identifier.name)

      assert %{metadata: new_content} = changes
      assert %{^identifier_name => ^existing_identifier} = new_content
    end

    test "keeps an already present identifier (i.e., editing) if extraneous identifier attr is passed",
         %{
           template_with_identifier: template_with_identifier,
           identifier_name: identifier_name
         } do
      # Existing identifier previously put by the create changeset
      existing_identifier = "00000000-0000-0000-0000-000000000000"

      grant_request = %GrantRequest{
        filters: %{"grant_filters" => "bar"},
        metadata: %{"old" => "foo", identifier_name => existing_identifier},
        domain_ids: [123]
      }

      params = %{
        group: build(:grant_request_group, user_id: 1),
        data_structure: build(:data_structure),
        metadata: %{
          "text" => "some text",
          identifier_name => "11111111-1111-1111-1111-111111111111"
        }
      }

      assert %Changeset{changes: changes} =
               GrantRequest.changeset(grant_request, params, template_with_identifier.name)

      assert %{metadata: new_content} = changes
      assert %{^identifier_name => ^existing_identifier} = new_content
    end

    test "puts an identifier if there is not already one and the template has an identifier field",
         %{
           template_without_identifier: template_without_identifier,
           identifier_name: identifier_name
         } do
      # %{id: domain_id} = CacheHelpers.insert_domain()
      # %{user_id: user_id} = claims = build(:claims, role: "user")

      grant_request = %GrantRequest{
        filters: %{"grant_filters" => "bar"},
        metadata: %{"old" => "foo"},
        domain_ids: [123]
      }

      params = %{
        group: build(:grant_request_group, user_id: 1),
        data_structure: build(:data_structure),
        metadata: %{"text" => "some text"}
      }

      assert %Changeset{changes: changes} =
               GrantRequest.changeset(grant_request, params, template_without_identifier.name)

      assert %{metadata: new_content} = changes
      refute match?(%{^identifier_name => _identifier}, new_content)
    end
  end
end
