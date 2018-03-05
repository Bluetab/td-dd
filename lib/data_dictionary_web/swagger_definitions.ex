defmodule DataDictionaryWeb.SwaggerDefinitions do
  @moduledoc """
   Swagger definitions used by controllers
  """
  import PhoenixSwagger

  def data_structure_swagger_definitions do
    %{
      DataStructure: swagger_schema do
        title "Data Structure"
        description "A Data Structure"
        properties do
          id :integer, "Data Structure unique identifier", required: true
          system :string, "Data Structure system", required: true
          group :string, "Data Structure group", required: true
          name :string, "Data Structure name", required: true
          description :string, "Data Structure description"
          last_change_by :integer, "Data Structure last updated by"
          last_change_at :string, "Data Structure last updated at"
      end
        example %{
        id: 123,
        system: "Data Structure system",
        group: "Data Structure group",
        name: "Data Structure name",
        description: "Data Structure description",
        }
      end,
      DataStructureCreate: swagger_schema do
        properties do
          data_structure (Schema.new do
            properties do
              system :string, "Data Structure system", required: true
              group :string, "Data Structure group", required: true
              name :string, "Data Structure name", required: true
              description :string, "Data Structure description"
            end
          end)
        end
      end,
      DataStructures: swagger_schema do
        title "Data Structures"
        description "A collection of Data Structures"
        type :array
        items Schema.ref(:DataStructure)
      end,
      DataStructureResponse: swagger_schema do
        properties do
          data Schema.ref(:DataStructure)
        end
      end,
      DataStructuresResponse: swagger_schema do
        properties do
          data Schema.ref(:DataStructures)
        end
      end
    }
  end

end
