defmodule TdDdWeb.SwaggerDefinitions do
  @moduledoc """
   Swagger definitions used by controllers
  """
  import PhoenixSwagger

  def relation_type_definitions do
    %{
      RelationTypeResponse:
        swagger_schema do
          properties do
            data(Schema.ref(:RelationType))
          end
        end,
      RelationTypesResponse:
        swagger_schema do
          properties do
            data(Schema.ref(:RelationTypes))
          end
        end,
      UpdateRelationType:
        swagger_schema do
          properties do
            relation_type(Schema.ref(:RelationTypeEdit))
          end
        end,
      CreateRelationType:
        swagger_schema do
          properties do
            relation_type(Schema.ref(:RelationTypeEdit))
          end
        end,
      RelationType:
        swagger_schema do
          title("RelationType")
          description("Representation of a RelationType")

          properties do
            id(:integer, "Relation Type Id", required: true)
            name(:string, "Relation Type name", required: true)
            description(:string, "Relation Type description", required: false)
          end
        end,
      RelationTypes:
        swagger_schema do
          title("RelationTypes")
          description("A collection of relation type")
          type(:array)
          items(Schema.ref(:RelationType))
        end,
      RelationTypeEdit:
        swagger_schema do
          properties do
            name(:string, "Relation Type name")
            description(:string, "Relation Type description")
          end
        end
    }
  end

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
            ancestry(Schema.ref(:DataStructuresEmbedded))
            children(Schema.ref(:DataStructuresEmbedded))
            data_structure(Schema.ref(:DataStructure))
            parent(Schema.ref(:DataStructuresEmbedded))
            siblings(Schema.ref(:DataStructuresEmbedded))
            relations(Schema.ref(:EmbeddedRelation))
            system(:object, "Data Structure system", required: true)
            version(:integer, "Version number", required: true)
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
            group(:string, "Data Structure group")
            name(:string, "Data Structure name")
            domain_id([:integer, :null], "Domain Id")
            class([:string, :null], "Data Structure class")
            description([:string, :null], "Data Structure description")
            external_id([:string, :null], "Data Structure external id")
            type([:string, :null], "Data Structure type (csv, table...)")
            confidential(:boolean, "Data Structure confidentiality")
            updated_at(:string, "Data Structure last updated at")
            inserted_at(:string, "Data Structure creation date")
            metadata(:object, "Data Structure data. Uploaded by background processes")
            parent(Schema.ref(:DataStructuresEmbedded))
            children(Schema.ref(:DataStructuresEmbedded))
            siblings(Schema.ref(:DataStructuresEmbedded))
            ancestry(Schema.ref(:DataStructuresEmbedded))
            relations(Schema.ref(:EmbeddedRelation))
            versions(:array, "Versions", items: Schema.ref(:Version))
          end

          example(%{
            id: 123,
            system: %{
              id: 1,
              external_id: "ExId",
              name: "My Name"
            },
            group: "Data Structure group",
            name: "Data Structure name",
            description: "Data Structure description",
            type: "Csv",
            confidential: "Data Structure confidentiality",
            inserted_at: "2018-05-08T17:17:59.691460",
            system_id: 1,
            data_fields: [],
            metadata: %{
              "description" => "last description",
              "updated_at" => "2018-05-08T17:17:59.691460"
            }
          })
        end,
      Relation:
        swagger_schema do
        title("Relation")
        properties do
          structure(Schema.ref(:DataStructureEmbedded))
          relation_type(Schema.ref(:RelationType))
        end
      end,
      Relations:
        swagger_schema do
          title("Relations")
          description("Relation collection")
          type(:array)
          items(Schema.ref(:Relation))
      end,
      EmbeddedRelation:
        swagger_schema do
          title("Embedded Relation")
          description("An embedded Data Structure")

          properties do
            parents(Schema.ref(:Relations))
            children(Schema.ref(:Relations))
          end
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
                end
              end
            )
          end
        end,
      BulkUpdateRequest:
        swagger_schema do
          properties do
            bulk_update_request(
              Schema.new do
                properties do
                  update_attributes(:object, "Update attributes")
                  search_params(:object, "Search params")
                end
              end
            )
          end
        end,
      CsvRequest:
        swagger_schema do
          properties do
            csv_request(
              Schema.new do
                properties do
                  search_params(:object, "Search params")
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
      DataStructureIDs:
        swagger_schema do
          title("Data Structure IDs updated")
          description("An array of Data Structure IDs")
          type(:array)
          items(%{type: :integer})
        end,
      BulkUpdateResponse:
        swagger_schema do
          properties do
            data(
              Schema.new do
                properties do
                  message(Schema.ref(:DataStructureIDs))
                end
              end
            )
          end
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

  def system_swagger_definitions do
    %{
      System:
        swagger_schema do
          title("System")
          description("A System")

          properties do
            id(:integer, "System unique identifier", required: true)
            external_id(:string, "Id representing a system externally", required: true)
            name(:string, "System's name", required: true)
          end

          example(%{
            name: "MicroStrategy",
            external_id: "MS01",
            id: 1
          })
        end,
      SystemCreate:
        swagger_schema do
          properties do
            system(
              Schema.new do
                properties do
                  external_id(:string, "Id representing a system externally", required: true)
                  name(:string, "System's name", required: true)
                end
              end
            )
          end
        end,
      SystemUpdate:
        swagger_schema do
          properties do
            system(
              Schema.new do
                properties do
                  external_id(:string, "Id representing a system externally")
                  name(:string, "System's name")
                end
              end
            )
          end
        end,
      Systems:
        swagger_schema do
          title("Systems")
          description("A collection of Systems")
          type(:array)
          items(Schema.ref(:System))
        end,
      SystemResponse:
        swagger_schema do
          properties do
            data(Schema.ref(:System))
          end
        end,
      SystemsResponse:
        swagger_schema do
          properties do
            data(Schema.ref(:Systems))
          end
        end
    }
  end

  def group_swagger_definitions do
    %{
      GroupsResponse:
        swagger_schema do
          properties do
            data(:array, "Group names")
          end

          example(%{
            data: ["group 1", "group 2"]
          })
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
        end,
      FilterRequest:
        swagger_schema do
          properties do
            filters(:object, "Filters", required: false)
          end

          example(%{
            filters: %{
              domain: ["Domain1", "Domain2"],
              status: ["draft"],
              data_owner: ["user1"]
            }
          })
        end
    }
  end
end
