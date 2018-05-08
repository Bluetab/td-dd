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
          type :string, "Data Structure type (csv, table...)"
          ou :string, "Data Structure organizational unit"
          lopd :string, "Data Structure lopd level"
          last_change_by :string, "Data Structure last updated by"
          last_change_at :string, "Data Structure last updated at"
          inserted_at :string, "Data Structure creation date"
      end
        example %{
        id: 123,
        system: "Data Structure system",
        group: "Data Structure group",
        name: "Data Structure name",
        description: "Data Structure description",
        type: "Csv",
        ou: "General Management",
        lopd: "1",
        inserted_at: "2018-05-08T17:17:59.691460"
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
              type :string, "Data Structure type (csv, table...)"
              ou :string, "Data Structure organizational unit"
              lopd :string, "Data Structure lopd level"
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
              type :string, "Data Structure type (csv, table...)"
              ou :string, "Data Structure organizational unit"
              lopd :string, "Data Structure lopd level"
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
          precision :string, "Data Field precision"
          nullable :boolean, "Data Field... is nullable"
          description :string, "Data Field descrition"
          business_concept_id :string, "Asociated Business Concept Id"
          data_structure_id :integer, "Belongs to Data Structure", required: true
          last_change_by :string, "Data Field last updated by"
          last_change_at :string, "Data Field last updated at"
          inserted_at :string, "Data Field creation date"
      end
        example %{
          id: 123,
          name: "Data Field name",
          type: "Data Field type",
          precision: "Data Field precision",
          nullable: true,
          description: "Data Field descrition",
          business_concept_id: "123456",
          data_structure_id: 11,
          last_change_by: 1,
          last_change_at: "2010-04-17 14:00:00",
          inserted_at: "2018-05-08T17:17:59.691460"
      }
      end,
      DataFieldCreate: swagger_schema do
        properties do
          data_structure (Schema.new do
            properties do
              name :string, "Data Field name", required: true
              type :string, "Data Field type"
              precision :string, "Data Field precision"
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

  def comment_swagger_definitions do
    %{
      Comment: swagger_schema do
        title "Comment"
        description "A Data Structure/Field Comment"
        properties do
          id :integer, "Comment unique identifier", required: true
          resource_id :integer, "Resource identifier", required: true
          resource_type :string, "Resource type", required: true
          user_id :integer, "User identifier", required: true
          content :string, "Comment content", required: true
      end
        example %{
          resource_id: 123,
          resource_type: "Field",
          user_id: 1,
          content: "This is a comment"
        }
      end,
      CommentCreate: swagger_schema do
        properties do
          comment (Schema.new do
            properties do
              resource_id :integer, "Resource identifier", required: true
              resource_type :string, "Resource type", required: true
              user_id :integer, "User identifier", required: true
              content :string, "Comment content", required: true
            end
          end)
        end
      end,
      CommentUpdate: swagger_schema do
        properties do
          comment (Schema.new do
            properties do
              id :integer, "Comment unique identifier", required: true
              resource_id :integer, "Resource identifier"
              resource_type :string, "Resource type"
              user_id :integer, "User identifier"
              content :string, "Comment content"
            end
          end)
        end
      end,
      Comments: swagger_schema do
        title "Comments"
        description "A collection of Comments"
        type :array
        items Schema.ref(:Comment)
      end,
      CommentResponse: swagger_schema do
        properties do
          data Schema.ref(:Comment)
        end
      end,
      CommentsResponse: swagger_schema do
        properties do
          data Schema.ref(:Comments)
        end
      end
    }
  end

end
