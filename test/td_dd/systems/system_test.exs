defmodule TdDd.Systems.SystemTest do
  use TdDd.DataCase

  alias Ecto.Changeset
  alias TdDd.Repo
  # alias TdDd.Systems.System # clashes with Elixir's System core module

  @template_name TdDd.Systems.System._test_get_template_name()

  setup do
    identifier_name = "identifier"

    with_identifier = %{
      id: System.unique_integer([:positive]),
      name: @template_name,
      label: "system_with_identifier",
      scope: "dd",
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

    template_with_identifier = CacheHelpers.insert_template(with_identifier)

    [
      template_with_identifier: template_with_identifier,
      identifier_name: identifier_name
    ]
  end

  describe "changeset/0" do
    test "detects missing required fields" do
      assert %{errors: errors} = TdDd.Systems.System.changeset(%{})
      assert length(errors) == 2
      assert {_message, [validation: :required]} = errors[:external_id]
      assert {_message, [validation: :required]} = errors[:name]
    end

    test "detects unique constraint violation" do
      insert(:system, external_id: "foo")

      assert {:error, %{errors: errors}} =
               :system
               |> build(external_id: "foo")
               |> Map.take([:external_id, :name])
               |> TdDd.Systems.System.changeset()
               |> Repo.insert()

      assert {_message, info} = errors[:external_id]
      assert info[:constraint] == :unique
    end
  end

  describe "changeset/1" do
    test "detects missing required fields" do
      system = insert(:system)
      assert %{errors: errors} = TdDd.Systems.System.changeset(system, %{external_id: nil, name: nil})
      assert length(errors) == 2
      assert {_message, [validation: :required]} = errors[:external_id]
      assert {_message, [validation: :required]} = errors[:name]
    end

    test "detects unique constraint violation" do
      insert(:system, external_id: "foo")
      system = insert(:system, external_id: "bar")

      assert {:error, %{errors: errors}} =
               system
               |> TdDd.Systems.System.changeset(%{external_id: "foo"})
               |> Repo.update()

      assert {_message, info} = errors[:external_id]
      assert info[:constraint] == :unique
    end

    test "create new system: puts a new identifier if the template has an identifier field", %{
      identifier_name: identifier_name
    } do
      attrs = %{
        external_id: "system_external_id",
        name: "system_name",
        df_content: %{"text" => "some text"}
      }

      assert %Changeset{changes: changes} =
        TdDd.Systems.System.changeset(attrs)

      assert %{df_content: new_content} = changes
      assert %{^identifier_name => _identifier} = new_content
    end

    test "keeps an already present identifier (i.e., editing)", %{
      identifier_name: identifier_name
    } do
      # Existing identifier previously put by the create changeset
      existing_identifier = "00000000-0000-0000-0000-000000000000"

      system = build(:system, df_content: %{identifier_name => existing_identifier})

      assert %Changeset{changes: changes} =
        TdDd.Systems.System.changeset(system, %{
                 df_content: %{"text" => "some update"}
               })

      assert %{df_content: new_content} = changes
      assert %{^identifier_name => ^existing_identifier} = new_content
    end

    test "keeps an already present identifier (i.e., editing) if extraneous identifier attr is passed", %{
      identifier_name: identifier_name
    } do
      # Existing identifier previously put by the create changeset
      existing_identifier = "00000000-0000-0000-0000-000000000000"

      system = build(:system, df_content: %{identifier_name => existing_identifier})

      assert %Changeset{changes: changes} =
        TdDd.Systems.System.changeset(system, %{
                 df_content: %{"text" => "some update", identifier_name => "11111111-1111-1111-1111-111111111111"}
               })

      assert %{df_content: new_content} = changes
      assert %{^identifier_name => ^existing_identifier} = new_content
    end

    test "puts an identifier if there is not already one and the template has an identifier field", %{
      identifier_name: identifier_name
    } do
      # System has no identifier but its template does
      # This happens if identifier is added to template after system creation
      # Test an update to the rule in this state.
      %{df_content: content} = system = build(:system)

      # Just to make sure factory does not add identifier
      refute match?(%{^identifier_name => _identifier}, content)

      assert %Changeset{changes: changes} =
        TdDd.Systems.System.changeset(system, %{
                 df_content: %{"text" => "some update"}
               })

      assert %{df_content: new_content} = changes
      assert %{^identifier_name => _identifier} = new_content
    end
  end
end
