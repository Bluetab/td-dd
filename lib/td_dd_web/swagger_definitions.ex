defmodule TdDdWeb.SwaggerDefinitions do
  @moduledoc """
   Swagger definitions used by controllers
  """
  import PhoenixSwagger

  def data_structure_version_swagger_definitions do
    %{
      DataStructureVersionResponse:
        swagger_schema do
          properties do
            data(Schema.ref(:DataStructureVersion))
          end
        end,
      DataStructureVersion:
        swagger_schema do
          title("Data Structure Version")
          description("A specific version of a Data Structure")

          properties do
            id(:integer, "Data Structure version unique identifier", required: true)
            version(:integer, "Version number", required: true)
            data_structure(Schema.ref(:DataStructure))
            data_fields(Schema.ref(:DataFields))
            parent(Schema.ref(:DataStructuresEmbedded))
            children(Schema.ref(:DataStructuresEmbedded))
            siblings(Schema.ref(:DataStructuresEmbedded))
            versions(:array, "Versions", items: Schema.ref(:Version))
          end
        end,
      Version:
        swagger_schema do
          title("Version")
          description("A version")

          properties do
            version(:integer, "Version number", required: true)
            inserted_at(:string, "Insertion date")
            updated_at(:string, "Modification date")
          end
        end
    }
  end

  def data_structure_swagger_definitions do
    %{
      DataStructure:
        swagger_schema do
          title("Data Structure")
          description("A Data Structure")

          properties do
            id(:integer, "Data Structure unique identifier", required: true)
            system(:object, "Data Structure system", required: true)
            system_id(:integer, "System Id", required: true)
            group(:string, "Data Structure group", required: true)
            name(:string, "Data Structure name", required: true)
            description([:string, :null], "Data Structure description")
            type([:string, :null], "Data Structure type (csv, table...)")
            ou([:string, :null], "Data Structure organizational unit")
            confidential(:boolean, "Data Structure confidentiality")
            last_change_at(:string, "Data Structure last updated at")
            inserted_at(:string, "Data Structure creation date")
            data_fields(Schema.ref(:DataFields))
            metadata(:object, "Data Structure data. Uploaded by background processes")
            parent(Schema.ref(:DataStructuresEmbedded))
            children(Schema.ref(:DataStructuresEmbedded))
            siblings(Schema.ref(:DataStructuresEmbedded))
            versions(:array, "Versions", items: Schema.ref(:Version))
          end

          example(%{
            id: 123,
            system: %{
              id: 1,
              external_ref: "ExId",
              name: "My Name"
            },
            group: "Data Structure group",
            name: "Data Structure name",
            description: "Data Structure description",
            type: "Csv",
            ou: "General Management",
            confidential: "Data Structure confidentiality",
            inserted_at: "2018-05-08T17:17:59.691460",
            system_id: 1,
            data_fields: [],
            metadata: %{
              "description" => "last description",
              "ou" => "Super Management",
              "last_change_at" => "2018-05-08T17:17:59.691460"
            }
          })
        end,
      DataStructureEmbedded:
        swagger_schema do
          title("Embedded Data Structure")
          description("An embedded Data Structure")

          properties do
            id(:integer, "Data Structure unique identifier", required: true)
            name(:string, "Data Structure name", required: true)
            type([:string, :null], "Data Structure type (csv, table...)")
          end

          example(%{
            id: 123,
            name: "Data Structure name",
            type: "Csv"
          })
        end,
      DataStructureCreate:
        swagger_schema do
          properties do
            data_structure(
              Schema.new do
                properties do
                  system_id(:integer, "System id", required: true)
                  group(:string, "Data Structure group", required: true)
                  name(:string, "Data Structure name", required: true)
                  description(:string, "Data Structure description")
                  type(:string, "Data Structure type (csv, table...)")
                  ou(:string, "Data Structure organizational unit")
                  confidential(:boolean, "Data Structure confidentiality")
                end
              end
            )
          end
        end,
      DataStructureUpdate:
        swagger_schema do
          properties do
            data_structure(
              Schema.new do
                properties do
                  description(:string, "Data Structure description")
                  ou(:string, "Data Structure organizational unit")
                end
              end
            )
          end
        end,
      DataStructures:
        swagger_schema do
          title("Data Structures")
          description("A collection of Data Structures")
          type(:array)
          items(Schema.ref(:DataStructure))
        end,
      DataStructuresEmbedded:
        swagger_schema do
          title("Embedded Data Structures")
          description("A collection of embedded Data Structures")
          type(:array)
          items(Schema.ref(:DataStructureEmbedded))
        end,
      DataStructureResponse:
        swagger_schema do
          properties do
            data(Schema.ref(:DataStructure))
          end
        end,
      DataStructuresResponse:
        swagger_schema do
          properties do
            data(Schema.ref(:DataStructures))
            filters(:object, "Filters", required: false)
          end
        end,
      DataStructureSearchRequest:
        swagger_schema do
          properties do
            query(:string, "Query string", required: false)
            filters(:object, "Filters", required: false)
          end

          example(%{
            query: "searchterm",
            filters: %{
              name: ["KNA1", "KNB1"],
              system: ["Oracle"]
            }
          })
        end
    }
  end

  def data_field_swagger_definitions do
    %{
      DataField:
        swagger_schema do
          title("Data Field")
          description("A Data Structure Data Field")

          properties do
            id(:integer, "Data Field unique identifier", required: true)
            name(:string, "Data Field name", required: true)
            type([:string, :null], "Data Field type")
            precision([:string, :null], "Data Field precision")
            nullable([:boolean, :null], "Data Field... is nullable")
            description([:string, :null], "Data Field descrition")
            business_concept_id([:string, :null], "Asociated Business Concept Id")
            last_change_at(:string, "Data Field last updated at")
            inserted_at(:string, "Data Field creation date")
            metadata(:object, "Data Field data. Uploaded by background processes")
            external_id([:string, :null], "Data Field External ID")
          end

          example(%{
            id: 123,
            name: "Data Field name",
            type: "Data Field type",
            precision: "Data Field precision",
            nullable: true,
            description: "Data Field descrition",
            business_concept_id: "123456",
            last_change_at: "2010-04-17 14:00:00",
            inserted_at: "2018-05-08T17:17:59.691460",
            metadata: %{
              "description" => "last description",
              "last_change_at" => "2018-05-08T17:17:59.691460"
            },
            external_id: "External ID"
          })
        end,
      DataFieldCreate:
        swagger_schema do
          properties do
            data_field(
              Schema.new do
                properties do
                  name(:string, "Data Field name", required: true)
                  type(:string, "Data Field type")
                  precision(:string, "Data Field precision")
                  nullable(:boolean, "Data Field... is nullable")
                  description(:string, "Data Field descrition")
                  business_concept_id(:string, "Asociated Business Concept Id")
                end
              end
            )
          end
        end,
      DataFieldUpdate:
        swagger_schema do
          properties do
            data_field(
              Schema.new do
                properties do
                  description(:string, "Data Field description")
                end
              end
            )
          end
        end,
      DataFields:
        swagger_schema do
          title("Data Fields")
          description("A collection of Data Fields")
          type(:array)
          items(Schema.ref(:DataField))
        end,
      DataFieldResponse:
        swagger_schema do
          properties do
            data(Schema.ref(:DataField))
          end
        end,
      DataFieldsResponse:
        swagger_schema do
          properties do
            data(Schema.ref(:DataFields))
          end
        end
    }
  end

  def comment_swagger_definitions do
    %{
      Comment:
        swagger_schema do
          title("Comment")
          description("A Data Structure/Field Comment")

          properties do
            id(:integer, "Comment unique identifier", required: true)
            resource_id(:integer, "Resource identifier", required: true)
            resource_type(:string, "Resource type", required: true)
            user_id(:integer, "User identifier", required: true)
            content(:string, "Comment content", required: true)
          end

          example(%{
            resource_id: 123,
            resource_type: "Field",
            user_id: 1,
            content: "This is a comment"
          })
        end,
      CommentCreate:
        swagger_schema do
          properties do
            comment(
              Schema.new do
                properties do
                  resource_id(:integer, "Resource identifier", required: true)
                  resource_type(:string, "Resource type", required: true)
                  content(:string, "Comment content", required: true)
                end
              end
            )
          end
        end,
      CommentUpdate:
        swagger_schema do
          properties do
            comment(
              Schema.new do
                properties do
                  content(:string, "Comment content")
                end
              end
            )
          end
        end,
      Comments:
        swagger_schema do
          title("Comments")
          description("A collection of Comments")
          type(:array)
          items(Schema.ref(:Comment))
        end,
      CommentResponse:
        swagger_schema do
          properties do
            data(Schema.ref(:Comment))
          end
        end,
      CommentsResponse:
        swagger_schema do
          properties do
            data(Schema.ref(:Comments))
          end
        end
    }
  end

  def filter_swagger_definitions do
    %{
      FilterResponse:
        swagger_schema do
          title("Filters")

          description(
            "An object whose keys are filter names and values are arrays of filterable values"
          )

          properties do
            data(:object, "Filter values", required: true)
          end

          example(%{
            data: %{
              system: ["SAP", "SAS"],
              name: ["KNA1", "KNB1"]
            }
          })
        end
    }
  end
end
