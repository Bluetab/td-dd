defmodule TdDd.DictionaryTest do
  use Cabbage.Feature, async: false, file: "dictionary.feature"
  use TdDdWeb.ConnCase

  import TdDdWeb.Router.Helpers
  import TdDdWeb.ResponseCode
  import TdDdWeb.Authentication, only: :functions

  alias Poison, as: JSON
  alias TdDdWeb.ApiServices.MockTdAuditService
  alias TdDdWeb.ApiServices.MockTdAuthService

  @endpoint TdDdWeb.Endpoint
  @headers {"Content-type", "application/json"}
  @fixed_data_structure_values %{
    "System" => "system",
    "Group" => "group",
    "Name" => "name",
    "Description" => "description",
    "Type" => "type",
    "Organizational Unit" => "ou",
    "LOPD" => "lopd",
    "Last Modification" => "last_change_at"
  }
  @fixed_data_field_values %{
    "Field Name" => "name",
    "Type" => "type",
    "Precision" => "precision",
    "Nullable" => "nullable",
    "Business Concept ID" => "business_concept_id",
    "Description" => "description",
    "Last Modification" => "last_change_at",
    "Bc_related" => "bc_related"
  }

  setup_all do
    start_supervised(MockTdAuthService)
    start_supervised(MockTdAuditService)
    :ok
  end

  # Scenario: Create a new Data Structure

  defwhen ~r/^"(?<user_name>[^"]+)" tries to create a Data Structure with following data:$/,
          %{user_name: user_name, table: fields},
          state do
    token = get_user_token(user_name)
    attrs = field_value_to_api_attrs(fields, @fixed_data_structure_values)
    {:ok, status_code, _} = data_structure_create(token, attrs)
    {:ok, Map.merge(state, %{status_code: status_code})}
  end

  defthen ~r/^the system returns a result with code "(?<status_code>[^"]+)"$/,
          %{status_code: status_code},
          %{status_code: http_status_code} do
    assert status_code == to_response_code(http_status_code)
  end

  defand ~r/^"(?<user_name>[^"]+)" is able to view data structure system "(?<system>[^"]+)" group "(?<group>[^"]+)" and structure "(?<structure>[^"]+)"  with following data:$/,
         %{
           user_name: user_name,
           system: system,
           group: group,
           structure: structure,
           table: fields
         },
         _state do
    token = get_user_token(user_name)
    attrs = field_value_to_api_attrs(fields, @fixed_data_structure_values)
    data_structure_tmp = data_structure_find(token, system, group, structure) |> IO.inspect
    assert data_structure_tmp

    {:ok, http_status_code, %{"data" => data_structure}} =
      data_structure_show(token, data_structure_tmp["id"])

    assert rc_ok() == to_response_code(http_status_code)
    assert_attrs(attrs, data_structure)
  end

  # Scenario: Create a new field related to an existing Data Structure inside Data Dictionary

  defgiven ~r/^and existing data structure with following data:$/, %{table: fields}, state do
    token_admin = get_user_token("app-admin")
    attrs = field_value_to_api_attrs(fields, @fixed_data_structure_values)
    {:ok, http_status_code, _} = data_structure_create(token_admin, attrs)
    assert rc_created() == to_response_code(http_status_code)
    {:ok, Map.merge(state, %{token_admin: token_admin})}
  end

  defwhen ~r/^"(?<user_name>[^"]+)" tries to create a Data Field from system "(?<system>[^"]+)" group "(?<group>[^"]+)" and structure "(?<structure>[^"]+)" with following data:$/,
          %{
            user_name: user_name,
            system: system,
            group: group,
            structure: structure,
            table: fields
          },
          %{token_admin: token_admin} = state do
    data_structure = data_structure_find(token_admin, system, group, structure)

    attrs =
      fields
      |> field_value_to_data_field
      |> Map.put("data_structure_id", data_structure["id"])

    token = get_user_token(user_name)
    {:ok, status_code, _} = data_field_create(token, attrs)
    {:ok, Map.merge(state, %{status_code: status_code})}
  end

  defand ~r/^"(?<user_name>[^"]+)" is able to view data field "(?<field_name>[^"]+)" from system "(?<system>[^"]+)" group "(?<group>[^"]+)" and structure "(?<structure>[^"]+)" with following data:$/,
         %{
           user_name: user_name,
           field_name: field_name,
           system: system,
           group: group,
           structure: structure,
           table: fields
         },
         %{token_admin: token_admin} = _state do
    IO.inspect([system, group, structure, field_name])
    data_structure = data_structure_find(token_admin, system, group, structure) |> IO.inspect
    data_field_tmp = data_field_find(token_admin, field_name)
    assert data_field_tmp
    token = get_user_token(user_name)

    {:ok, http_status_code, %{"data" => data_field}} =
      data_field_show(token, data_field_tmp["id"])

    assert rc_ok() == to_response_code(http_status_code)
    attrs = field_value_to_data_field(fields)
    assert_attrs(attrs, data_field)
  end

  defwhen ~r/^"(?<user_name>[^"]+)" tries to load dictionary data with following information:$/,
          %{user_name: user_name, table: fields},
          state do
    metadata = build_metadata({[], []}, fields)

    data_structures_headers = ["system", "group", "name", "description", "type", "ou"]

    data_fields_headers = [
      "system",
      "group",
      "name",
      "field_name",
      "type",
      "description",
      "nullable",
      "precision",
      "business_concept_id"
    ]

    data_structures =
      metadata
      |> elem(0)
      |> List.insert_at(0, data_structures_headers)
      |> CSV.encode(separator: ?;)
      |> Enum.to_list()
      |> Enum.join()

    data_fields =
      metadata
      |> elem(1)
      |> List.insert_at(0, data_fields_headers)
      |> CSV.encode(separator: ?;)
      |> Enum.to_list()
      |> Enum.join()

    token = get_user_token(user_name)
    {:ok, status_code} = metadata_upload(token, data_structures, data_fields)

    {:ok, Map.merge(state, %{status_code: status_code, token_admin: get_user_token("app-admin")})}
  end

  defp field_value_to_data_field(field_value) do
    field_value
    |> field_value_to_api_attrs(@fixed_data_field_values)
    |> Map.update("nullable", false, &(&1 == "YES"))
    |> Map.update("business_concept_id", nil, &if(&1 == "", do: nil, else: &1))
  end

  defp field_value_to_api_attrs(field_value, fixed_values) do
    Enum.reduce(field_value, %{}, fn x, acc ->
      Map.put(acc, Map.get(fixed_values, x."Field", x."Field"), x."Value")
    end)
  end

  defp assert_attr("last_change_at" = attr, _value, %{} = target) do
    assert :ok == elem(DateTime.from_iso8601(target[attr]), 0)
  end

  defp assert_attr("nullable" = attr, value, %{} = target) do
    assert target[attr] == (value == "YES")
  end

  defp assert_attr(attr, value, %{} = target) do
    assert value == target[attr]
  end

  defp assert_attrs(%{} = attrs, %{} = target) do
    Enum.each(attrs, fn {attr, value} -> assert_attr(attr, value, target) end)
  end

  defp build_metadata(metadata, %{
         File: "Data Structure",
         Description: description,
         Group: group,
         Structure_Name: name,
         System: system,
         Type: type,
         Domain_Name: ou
       }) do
    data_structures = elem(metadata, 0)
    put_elem(metadata, 0, [[system, group, name, description, type, ou] | data_structures])
  end

  defp build_metadata(metadata, %{
         File: "Field",
         Description: description,
         Group: group,
         Structure_Name: name,
         System: system,
         Field_Name: field_name,
         Type: type,
         Precision: precision,
         Nullable: raw_nullable,
         Business_Concept_ID: business_concept_id
       }) do
    data_fields = elem(metadata, 1)
    nullable = if raw_nullable == "YES", do: "1", else: "0"

    put_elem(metadata, 1, [
      [
        system,
        group,
        name,
        field_name,
        type,
        description,
        nullable,
        precision,
        business_concept_id
      ]
      | data_fields
    ])
  end

  defp build_metadata(metadata, [head | tail]) do
    metadata
    |> build_metadata(head)
    |> build_metadata(tail)
  end

  defp build_metadata(metadata, []), do: metadata

  defp data_structure_create(token, attrs) do
    headers = [@headers, {"authorization", "Bearer #{token}"}]
    body = %{"data_structure" => attrs} |> JSON.encode!()

    %HTTPoison.Response{status_code: status_code, body: resp} =
      HTTPoison.post!(data_structure_url(@endpoint, :create), body, headers, [])

    {:ok, status_code, resp |> JSON.decode!()}
  end

  defp data_structure_show(token, id) do
    headers = [@headers, {"authorization", "Bearer #{token}"}]

    %HTTPoison.Response{status_code: status_code, body: resp} =
      HTTPoison.get!(data_structure_url(@endpoint, :show, id), headers, [])

    {:ok, status_code, resp |> JSON.decode!()}
  end

  defp data_structure_find(token, system, group, name) do
    {:ok, _, %{"data" => data_structure}} = data_structure_index(token)

    Enum.find(
      data_structure,
      &(&1["system"] == system && &1["group"] == group && &1["name"] == name)
    )
  end

  defp data_structure_index(token) do
    headers = get_header(token)

    %HTTPoison.Response{status_code: status_code, body: resp} =
      HTTPoison.get!(data_structure_url(@endpoint, :index), headers, [])

    {:ok, status_code, resp |> JSON.decode!()}
  end

  defp data_field_create(token, attrs) do
    headers = [@headers, {"authorization", "Bearer #{token}"}]
    body = %{"data_field" => attrs} |> JSON.encode!()

    %HTTPoison.Response{status_code: status_code, body: resp} =
      HTTPoison.post!(data_field_url(@endpoint, :create), body, headers, [])

    {:ok, status_code, resp |> JSON.decode!()}
  end

  defp data_field_show(token, id) do
    headers = [@headers, {"authorization", "Bearer #{token}"}]

    %HTTPoison.Response{status_code: status_code, body: resp} =
      HTTPoison.get!(data_field_url(@endpoint, :show, id), headers, [])

    {:ok, status_code, resp |> JSON.decode!()}
  end

  defp data_field_find(token, name) do
    {:ok, _, %{"data" => data_structure}} = data_field_index(token)
    Enum.find(data_structure, &(&1["name"] == name))
  end

  defp data_field_index(token) do
    headers = get_header(token)

    %HTTPoison.Response{status_code: status_code, body: resp} =
      HTTPoison.get!(data_field_url(@endpoint, :index), headers, [])

    {:ok, status_code, resp |> JSON.decode!()}
  end

  defp metadata_upload(token, data_structures, data_fields) do
    headers = get_header(token)

    form =
      {:multipart,
       [
         {"file", data_structures,
          {"form-data", [{"name", "data_structures"}, {"filename", "data_structures.csv"}]},
          [{"Content-Type", "text/csv"}]},
         {"file", data_fields,
          {"form-data", [{"name", "data_fields"}, {"filename", "data_fields.csv"}]},
          [{"Content-Type", "text/csv"}]}
       ]}

    %HTTPoison.Response{status_code: status_code, body: _resp} =
      HTTPoison.post!(metadata_url(@endpoint, :upload), form, headers)

    {:ok, status_code}
  end
end
