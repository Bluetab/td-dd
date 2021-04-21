defmodule TdCx.ConfigurationsTest do
  use TdDd.DataCase

  alias TdCx.Configurations
  alias TdCx.Vault

  @valid_attrs %{
    content: %{"field2" => "mandatory"},
    external_id: "some external_id",
    type: "config"
  }
  @valid_secret_attrs %{
    content: %{"secret_field" => "secret_value", "public_field" => "public_value"},
    external_id: "some secret external_id",
    type: "secret_config"
  }
  @update_attrs %{
    content: %{"field2" => "updated mandatory"}
  }
  @invalid_attrs %{content: %{"field3" => "foo"}}
  @app_admin_template %{
    id: 1,
    name: "config",
    label: "app-admin",
    scope: "ca",
    content: [
      %{
        "name" => "New Group 1",
        "fields" => [
          %{
            "name" => "Field1",
            "type" => "string",
            "label" => "Multiple 1",
            "values" => nil,
            "cardinality" => "?"
          },
          %{
            "name" => "field2",
            "type" => "string",
            "label" => "Multiple 1",
            "values" => nil,
            "cardinality" => "1"
          }
        ]
      }
    ]
  }
  @secret_template %{
    id: 2,
    name: "secret_config",
    label: "secret_config",
    scope: "ca",
    content: [
      %{
        "name" => "Secret Group",
        "is_secret" => true,
        "fields" => [
          %{
            "name" => "secret_field",
            "type" => "string",
            "label" => "Secret Field",
            "values" => nil,
            "cardinality" => "?"
          }
        ]
      },
      %{
        "name" => "Not Secret Group",
        "fields" => [
          %{
            "name" => "public_field",
            "type" => "string",
            "label" => "Public Field",
            "values" => nil,
            "cardinality" => "1"
          }
        ]
      }
    ]
  }

  setup_all do
    template = Templates.create_template(@app_admin_template)
    secret_template = Templates.create_template(@secret_template)

    on_exit(fn ->
      Templates.delete(template)
      Templates.delete(secret_template)
    end)
  end

  describe "configurations" do
    alias TdCx.Configurations.Configuration

    test "list_configurations/2 returns filtered configurations" do
      claims = build(:cx_claims)
      configuration = insert(:configuration)

      assert Configurations.list_configurations(claims, %{type: configuration.type}) == [
               configuration
             ]

      assert Configurations.list_configurations(claims, %{type: "made_up"}) == []
    end

    test "get_configuration_by_external_id!/1 returns the configuration with given external_id" do
      external_id = "my_ext_id"
      configuration = insert(:configuration, external_id: external_id)
      assert Configurations.get_configuration_by_external_id!(external_id) == configuration
    end

    test "get_configuration_by_external_id!/2 returns the configuration with secrets if whe hace permissions" do
      claims = build(:cx_claims, user_name: @valid_secret_attrs.type, role: "admin")

      {:ok, %Configuration{} = configuration} =
        Configurations.create_configuration(@valid_secret_attrs)

      assert %{content: %{"public_field" => "public_value", "secret_field" => "secret_value"}} =
               Configurations.get_configuration_by_external_id!(claims, configuration.external_id)

      claims = build(:cx_claims, user_name: @valid_secret_attrs.type, role: "user")

      content =
        Configurations.get_configuration_by_external_id!(claims, configuration.external_id).content

      assert is_nil(Map.get(content, "secret_field"))

      claims = build(:cx_claims, user_name: "foo", role: "admin")

      content =
        Configurations.get_configuration_by_external_id!(claims, configuration.external_id).content

      assert is_nil(Map.get(content, "secret_field"))
    end

    test "create_configuration/1 with valid data creates a configuration" do
      assert {:ok, %Configuration{} = configuration} =
               Configurations.create_configuration(@valid_attrs)

      assert configuration.content == %{"field2" => "mandatory"}

      assert configuration.external_id == "some external_id"
      assert configuration.type == "config"
      assert is_nil(configuration.secrets_key)
    end

    test "create_configuration/1 with valid data creates a configuration with secrets" do
      claims = build(:cx_claims, user_name: @valid_secret_attrs.type, role: "admin")

      assert {:ok, %Configuration{} = configuration} =
               Configurations.create_configuration(@valid_secret_attrs)

      assert configuration.content == %{"public_field" => "public_value"}
      assert configuration.external_id == "some secret external_id"
      assert configuration.type == "secret_config"
      refute is_nil(configuration.secrets_key)

      assert %{content: %{"public_field" => "public_value", "secret_field" => "secret_value"}} =
               Configurations.get_configuration_by_external_id!(claims, configuration.external_id)
    end

    test "create_configuration/1 with repeated external_id returns error changeset" do
      assert {:ok, %Configuration{}} = Configurations.create_configuration(@valid_attrs)

      assert {:error, %Ecto.Changeset{errors: [external_id: {_message, constraint}]}} =
               Configurations.create_configuration(@valid_attrs)

      assert Keyword.get(constraint, :constraint) == :unique
    end

    test "create_configuration/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Configurations.create_configuration(@invalid_attrs)
    end

    test "update_configuration/2 with valid data updates the configuration" do
      configuration = insert(:configuration)

      assert {:ok, %Configuration{} = configuration} =
               Configurations.update_configuration(configuration, @update_attrs)

      assert configuration.content == %{"field2" => "updated mandatory"}
    end

    test "update_configuration/2 with valid data updates the configuration with secrets" do
      claims = build(:cx_claims, user_name: @valid_secret_attrs.type, role: "admin")

      {:ok, %Configuration{} = configuration} =
        Configurations.create_configuration(@valid_secret_attrs)

      updated_content = %{
        "secret_field" => "updated secret_value",
        "public_field" => "updated public_value"
      }

      assert {:ok, %Configuration{} = configuration} =
               Configurations.update_configuration(configuration, %{content: updated_content})

      assert configuration.content == %{"public_field" => "updated public_value"}

      assert %{content: ^updated_content} =
               Configurations.get_configuration_by_external_id!(claims, configuration.external_id)
    end

    test "update_configuration/2 with invalid data returns error changeset" do
      configuration = insert(:configuration)

      assert {:error, %Ecto.Changeset{}} =
               Configurations.update_configuration(configuration, @invalid_attrs)

      assert configuration ==
               Configurations.get_configuration_by_external_id!(configuration.external_id)
    end

    test "delete_configuration/1 deletes the configuration" do
      configuration = insert(:configuration)
      assert {:ok, %Configuration{}} = Configurations.delete_configuration(configuration)

      assert_raise Ecto.NoResultsError, fn ->
        Configurations.get_configuration_by_external_id!(configuration.external_id)
      end
    end

    test "delete_configuration/1 deletes its vault secrets" do
      {:ok, %Configuration{secrets_key: secrets_key} = configuration} =
        Configurations.create_configuration(@valid_secret_attrs)

      assert %{"secret_field" => "secret_value"} == Vault.read_secrets(secrets_key)

      assert {:ok, %Configuration{}} = Configurations.delete_configuration(configuration)

      assert %{} == Vault.read_secrets(secrets_key)
    end
  end
end
