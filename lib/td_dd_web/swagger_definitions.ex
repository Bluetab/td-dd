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

  def structure_note_swagger_definitions do
    %{
      StructureNote:
        swagger_schema do
          title("Structure Note")
          description("A Structure Note")

          properties do
            id(:integer, "Structure Note unique identifier", required: true)
            data_structure(Schema.ref(:DataStructure))
            status(:string, "Status", required: true)
            version(:integer, "Version", required: true)
            df_content(:object, "Note Content", required: true)
          end

          example(%{
            id: 34,
            status: :draft,
            version: 1,
            df_content: %{"foo" => "bar"}
          })
        end,
      StructureNotes:
        swagger_schema do
          title("Structure Notes")
          description("A collection of structure notes")
          type(:array)
          items(Schema.ref(:StructureNote))
        end,
      StructureNotesResponse:
        swagger_schema do
          properties do
            data(Schema.ref(:StructureNotes))
          end
        end,
      CreateStructureNote:
        swagger_schema do
          properties do
            structure_note(
              Schema.new do
                properties do
                  df_content(:object, "Note Content", required: false)
                end
              end
            )
          end
        end,
      UpdateStructureNote:
        swagger_schema do
          properties do
            structure_note(
              Schema.new do
                properties do
                  status(:string, "Status", required: false)
                  df_content(:object, "Note Content", required: false)
                end
              end
            )
          end
        end,
      StructureNoteResponse:
        swagger_schema do
          properties do
            data(Schema.ref(:StructureNote))
          end
        end,
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
            metadata_versions(:array, "Metadata Versions", items: Schema.ref(:MetadataVersion))
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
        end,
      MetadataVersion:
        swagger_schema do
          title("Version")
          description("A version")

          properties do
            id(:integer, "Id of the metadata", required: true)
            version(:integer, "Version number", required: true)
            deleted_at(:string, "Deletion date")
            data_structure_id(:string, "Structure Id")
            fields(:object, "Fields composing the metadata")
          end
        end
    }
  end

  def data_structure_tag_definitions do
    %{
      DataStructureTag:
        swagger_schema do
          title("Data Structure Tag")
          description("A Data Structure Tag")

          properties do
            id(:integer, "Data Structure Tag unique identifier", required: true)
            name(:string, "Tag name")
            structure_count(:integer, "Linked structures count")
          end

          example(%{
            id: 88,
            name: "Tag1"
          })
        end,
      DataStructureTags:
        swagger_schema do
          title("DataStructureTags")
          description("A collection of data structure tags")
          type(:array)
          items(Schema.ref(:DataStructureTag))
        end,
      CreateDataStructureTag:
        swagger_schema do
          properties do
            data_structure_tag(
              Schema.new do
                properties do
                  name(:string, "Data Structure name", required: true)
                end
              end
            )
          end
        end,
      UpdateDataStructureTag:
        swagger_schema do
          properties do
            data_structure_tag(
              Schema.new do
                properties do
                  name(:string, "Data Structure name", required: true)
                end
              end
            )
          end
        end,
      DataStructureTagResponse:
        swagger_schema do
          properties do
            data(Schema.ref(:DataStructureTag))
          end
        end,
      DataStructureTagsResponse:
        swagger_schema do
          properties do
            data(Schema.ref(:DataStructureTags))
          end
        end,
      UpdateLinkDataStructureTag:
        swagger_schema do
          properties do
            tag(
              Schema.new do
                properties do
                  description(:string, "Tag description", required: true)
                end
              end
            )
          end
        end,
      LinksDataStructureTagResponse:
        swagger_schema do
          properties do
            data(Schema.ref(:LinksDataStructureTag))
          end
        end,
      LinksDataStructureTag:
        swagger_schema do
          title("LinksDataStructureTagResponse")
          description("Links between a structure and its tags")
          type(:array)
          items(Schema.ref(:LinkDataStructureTag))
        end,
      LinkDataStructureTag:
        swagger_schema do
          title("LinkDataStructureTag")
          description("Link between a structure and its tags")

          properties do
            id(:integer, "Id link")
            description(:string, "Tag description")
            _embedded(Schema.ref(:LinkDataStructureTagEmbeddings))
          end
        end,
      LinkDataStructureTagResponse:
        swagger_schema do
          properties do
            data(Schema.ref(:LinkDataStructureTag))
          end
        end,
      LinkDataStructureTagEmbeddings:
        swagger_schema do
          properties do
            data_structure(Schema.ref(:EmbeddedLinkedDataStructure))
            data_structure_tag(Schema.ref(:DataStructureTag))
          end
        end,
      EmbeddedLinkedDataStructure:
        swagger_schema do
          properties do
            id(:integer, "Data structure id")
            external_id(:string, "Data structure external id")
          end
        end
    }
  end

  def data_structure_type_definitions do
    %{
      DataStructureType:
        swagger_schema do
          title("Data Structure Type")
          description("A Data Structure Type")

          properties do
            id(:integer, "Data Structure Type unique identifier", required: true)
            structure_type(:string, "Structure type", required: true)
            template_id(:integer, "Template Id", required: true)
            translation(:string, "Default translation message")
            metadata_fields(:array, "Available metadata fields for this type")
          end

          example(%{
            id: 88,
            structure_type: "Table",
            template_id: 3,
            translation: "Tabla",
            metadata_fields: ["field_1", "field_2"]
          })
        end,
      DataStructureTypeWithTemplate:
        swagger_schema do
          title("Data Structure Type With template info")
          description("A Data Structure Type with template info")

          properties do
            id(:integer, "Data Structure Type unique identifier", required: true)
            structure_type(:string, "Structure type", required: true)
            template(:object, "Template Id and Name", required: true)
            translation(:string, "Default translation message")
            metadata_fields(:array, "Available metadata fields for this type")
          end

          example(%{
            id: 88,
            structure_type: "Table",
            template: %{id: 3, name: "TableTemplate"},
            translation: "Tabla",
            metadata_fields: ["field_1", "field_2"]
          })
        end,
      DataStructureTypes:
        swagger_schema do
          title("DataStructureTypes")
          description("A collection of data structure types")
          type(:array)
          items(Schema.ref(:DataStructureTypeWithTemplate))
        end,
      CreateDataStructureType:
        swagger_schema do
          properties do
            data_structure_type(
              Schema.new do
                properties do
                  structure_type(:string, "Data Structure type", required: true)
                  template_id(:integer, "Template Id", required: true)
                  translation(:string, "Default translation message")
                  metadata_fields(:array, "Available metadata fields for this type")
                end
              end
            )
          end
        end,
      UpdateDataStructureType:
        swagger_schema do
          properties do
            data_structure_type(
              Schema.new do
                properties do
                  template_id(:integer, "Template Id", required: true)
                  translation(:string, "Default translation message")
                  metadata_fields(:array, "Available metadata fields for this type")
                end
              end
            )
          end
        end,
      DataStructureTypeResponse:
        swagger_schema do
          properties do
            data(Schema.ref(:DataStructureType))
          end
        end,
      DataStructureTypesResponse:
        swagger_schema do
          properties do
            data(Schema.ref(:DataStructureTypes))
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

  def unit_swagger_definitions do
    %{
      Unit:
        swagger_schema do
          title("Unit")
          description("A Unit of lineage data")

          properties do
            name(:string, "unique name", required: true)
            status(Schema.ref(:UnitEvent))
            deleted_at(:string, "logical deletion timestamp")
            inserted_at(:string, "insert timestamp")
            updated_at(:string, "update timestamp")
          end
        end,
      Units:
        swagger_schema do
          title("Units")
          description("A collection of Units")
          type(:array)
          items(Schema.ref(:Unit))
        end,
      UnitEvent:
        swagger_schema do
          title("Unit Event")
          description("An event associated with a Unit")

          properties do
            event(:string, "event", required: true)
            info(:object, "event information")
            timestamp(:string, "event timestamp")
          end
        end,
      UnitEvents:
        swagger_schema do
          title("Unit Events")
          description("A collection of Unit Events")
          type(:array)
          items(Schema.ref(:UnitEvent))
        end,
      UnitResponse:
        swagger_schema do
          properties do
            data(Schema.ref(:Unit))
          end
        end,
      UnitsResponse:
        swagger_schema do
          properties do
            data(Schema.ref(:Units))
          end
        end,
      UnitEventsResponse:
        swagger_schema do
          properties do
            data(Schema.ref(:UnitEvents))
          end
        end
    }
  end

  def user_search_filters_definitions do
    %{
      UserSearchFilter:
        swagger_schema do
          title("User search filter")
          description("A User search filter")

          properties do
            id(:integer, "User search filter unique identifier", required: true)
            name(:string, "Name", required: true)
            user_id(:integer, "Current user id", required: true)
            filters(:object, "Search filters")
          end

          example(%{
            id: 5,
            name: "Tipo basic",
            user_id: 3,
            filters: %{
              "pais" => ["Australia", "", "Argelia"],
              "link_count" => ["linked_terms", "not_linked_terms"]
            }
          })
        end,
      UserSearchFilters:
        swagger_schema do
          title("UserSearchFilters")
          description("A collection of user search filter")
          type(:array)
          items(Schema.ref(:UserSearchFilter))
        end,
      CreateUserSearchFilter:
        swagger_schema do
          properties do
            user_search_filter(
              Schema.new do
                properties do
                  name(:string, "Search name", required: true)
                  filters(:object, "Search filters")
                end
              end
            )
          end
        end,
      UserSearchFilterResponse:
        swagger_schema do
          properties do
            data(Schema.ref(:UserSearchFilter))
          end
        end,
      UserSearchFiltersResponse:
        swagger_schema do
          properties do
            data(Schema.ref(:UserSearchFilters))
          end
        end
    }
  end

  def profile_execution_group_swagger_definitions do
    %{
      ProfileExecutionGroup:
        swagger_schema do
          title("Execution Group")
          description("A group of structure executions")

          properties do
            executions(Schema.ref(:ProfileExecutions))
            id(:integer, "Execution Group unique identifier", required: true)
            inserted_at(:string, "insert timestamp")
          end
        end,
      ProfileExecutions:
        swagger_schema do
          title("Executions")
          description("A collection of Executions")
          type(:array)
          items(Schema.ref(:ProfileExecution))
        end,
      ProfileExecution:
        swagger_schema do
          properties do
            id(:integer, "Execution unique identifier", required: true)
            inserted_at(:string, "insert timestamp")
            _embedded(Schema.ref(:ProfileExecutionEmbeddings))
          end
        end,
      ProfileExecutionEmbeddings:
        swagger_schema do
          properties do
            data_structure(Schema.ref(:EmbeddedStructure))
            profile(Schema.ref(:EmbeddedProfile))
            profile_events(Schema.ref(:EmbeddedProfileEvents))
          end
        end,
      EmbeddedStructure:
        swagger_schema do
          properties do
            id(:integer, "Structure unique identifier", required: true)
            external_id(:string, "Structure external id", required: true)
          end
        end,
      ProfileExecutionGroups:
        swagger_schema do
          title("Execution Groups")
          description("A collection of Execution Groups")
          type(:array)
          items(Schema.ref(:ProfileExecutionGroup))
        end,
      ProfileExecutionGroupResponse:
        swagger_schema do
          properties do
            data(Schema.ref(:ProfileExecutionGroup))
          end
        end,
      ProfileExecutionGroupsResponse:
        swagger_schema do
          properties do
            data(Schema.ref(:ProfileExecutionGroups))
          end
        end,
      ProfileExecutionsResponse:
        swagger_schema do
          properties do
            data(Schema.ref(:ProfileExecutions))
          end
        end,
      ProfileExecutionResponse:
        swagger_schema do
          properties do
            data(Schema.ref(:ProfileExecution))
          end
        end,
      EmbeddedProfile:
        swagger_schema do
          properties do
            id(:integer, "Profile identifier", required: true)
            data_structure_id(:integer, "Data structure id", required: true)
            value(:object, "Profile", required: false)
          end
        end
    }
  end

  def profile_event_swagger_definitions do
    %{
      ProfileEvent:
        swagger_schema do
          title("Profile Event")
          description("Representation of a event")

          properties do
            id(:integer, "Event Id", required: true)
            profile_execution_id(:integer, "Execution Id", required: true)
            inserted_at(:string, "Event insertion date")
            type([:string, :null], "Event type")
            message([:string, :null], "Event message")
          end
        end,
      ProfileEventResponse:
        swagger_schema do
          properties do
            data(Schema.ref(:ProfileEvent))
          end
        end,
      EmbeddedProfileEvents:
        swagger_schema do
          title("Profile Events")
          description("A collection of events")
          type(:array)
          items(Schema.ref(:ProfileEvent))
        end
    }
  end

  def classifier_swagger_definitions do
    %{
      Classifier:
        swagger_schema do
          title("Classifier")
          description("A classifier for data structures")

          properties do
            id(:integer, "Id", required: true)
            name(:string, "Name", required: true)
            filters(Schema.ref(:ClassifierFilters))
            rules(Schema.ref(:ClassifierRules))
          end
        end,
      Classifiers:
        swagger_schema do
          title("Classifiers")
          description("A collection of classifiers")
          type(:array)
          items(Schema.ref(:Classifier))
        end,
      ClassifierRequest:
        swagger_schema do
          properties do
            classifier(Schema.ref(:Classifier))
          end
        end,
      ClassifierResponse:
        swagger_schema do
          properties do
            data(Schema.ref(:Classifier))
          end
        end,
      ClassifiersResponse:
        swagger_schema do
          properties do
            data(Schema.ref(:Classifiers))
          end
        end,
      ClassifierFilters:
        swagger_schema do
          title("Classifier filters")
          description("A collection of filters")
          type(:array)
          items(Schema.ref(:ClassifierFilter))
        end,
      ClassifierFilter:
        swagger_schema do
          title("A classifier filter for matching data structures")
          description("Either regex or values must be present")

          properties do
            path(:array, "The path", required: true)
            regex(:string, "Regex")
            values(:array, "Values")
          end
        end,
      ClassifierRules:
        swagger_schema do
          title("Classifier rules")
          description("A collection of rules")
          type(:array)
          items(Schema.ref(:ClassifierRule))
        end,
      ClassifierRule:
        swagger_schema do
          title("A classifier rule for matching data structures")
          description("Either regex or values must be present")

          properties do
            path(:array, "The path", required: true)
            priority(:integer)
            class(:string, "Classification class", required: true)
            values(:array, "Values")
            regex(:string, "Regex")
          end
        end
    }
  end
end
