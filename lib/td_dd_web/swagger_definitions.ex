defmodule TdDdWeb.SwaggerDefinitions do
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
      DataStructureUpdate: swagger_schema do
        properties do
          data_structure (Schema.new do
            properties do
              id :integer, "Data Structure unique identifier", required: true
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

  def data_field_swagger_definitions do
    %{
      DataField: swagger_schema do
        title "Data Field"
        description "A Data Structure Data Field"
        properties do
          id :integer, "Data Field unique identifier", required: true
          name :string, "Data Field name", required: true
          type :string, "Data Field type"
          precision :integer, "Data Field precision"
          nullable :boolean, "Data Field... is nullable"
          description :string, "Data Field descrition"
          business_concept_id :string, "Asociated Business Concept Id"
          data_structure_id :integer, "Belongs to Data Structure", required: true
          last_change_by :integer, "Data Structure last updated by"
          last_change_at :string, "Data Structure last updated at"
      end
        example %{
          id: 123,
          name: "Data Field name",
          type: "Data Field type",
          precision: 12,
          nullable: true,
          description: "Data Field descrition",
          business_concept_id: "123456",
          data_structure_id: 11,
          last_change_by: 1,
          last_change_at: "2010-04-17 14:00:00"
        }
      end,
      DataFieldCreate: swagger_schema do
        properties do
          data_structure (Schema.new do
            properties do
              name :string, "Data Field name", required: true
              type :string, "Data Field type"
              precision :integer, "Data Field precision"
              nullable :boolean, "Data Field... is nullable"
              description :string, "Data Field descrition"
              business_concept_id :string, "Asociated Business Concept Id"
              data_structure_id :string, "Belongs to Data Structure", required: true
            end
          end)
        end
      end,
      DataFieldUpdate: swagger_schema do
        properties do
          data_structure (Schema.new do
            properties do
              id :integer, "Data Field unique identifier", required: true
              type :string, "Data Field type"
              precision :integer, "Data Field precision"
              nullable :boolean, "Data Field... is nullable"
              description :string, "Data Field descrition"
              business_concept_id :string, "Asociated Business Concept Id"
            end
          end)
        end
      end,
      DataFields: swagger_schema do
        title "Data Fields"
        description "A collection of Data Fields"
        type :array
        items Schema.ref(:DataField)
      end,
      DataFieldResponse: swagger_schema do
        properties do
          data Schema.ref(:DataField)
        end
      end,
      DataFieldsResponse: swagger_schema do
        properties do
          data Schema.ref(:DataFields)
        end
      end
    }
  end

end
