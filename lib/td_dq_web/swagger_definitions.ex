defmodule TdDqWeb.SwaggerDefinitions do
  @moduledoc """
   Swagger definitions used by controllers
  """
  import PhoenixSwagger

  def rule_definitions do
    %{
      Rule:
        swagger_schema do
          title("Rule")
          description("Rule entity")

          properties do
            id(:integer, "unique identifier", required: true)
            business_concept_id([:string, nil], "business concept id")
            description(:string, "description", required: true)
            goal(:integer, "goal percentage (1-100)")
            minimum(:integer, "minimum goal (1-100)")
            name(:string, "rule name")
            active(:boolean, "active (Default: false)")
            version(:integer, "version number")
            updated_by(:integer, "updated by user id")
            type_params(:object, "rule type_params")
            rule_type_id(:integer, "Belongs to rule type", required: true)
          end
        end,
      RuleDetail:
        swagger_schema do
          title("Rule Detail")
          description("Rule entity with possible system values to create an implementation")

          properties do
            id(:integer, "unique identifier", required: true)
            business_concept_id([:string, nil], "business concept id")
            description(:string, "description", required: true)
            goal(:integer, "goal percentage (1-100)")
            minimum(:integer, "minimum goal (1-100)")
            name(:string, "rule name")
            active(:boolean, "active (Default: false)")
            version(:integer, "version number")
            updated_by(:integer, "updated by user id")
            type_params(:object, "rule type_params")
            rule_type_id(:integer, "Belongs to rule type", required: true)
            system_values(:object, "Possible system values retrieved to create an implementation")
          end
        end,
      RuleImplementation:
        swagger_schema do
          title("Rule Implementation")
          description("Rule Implementation entity")

          properties do
            id(:integer, "Rule Implementation unique identifier", required: true)
            implementation_key(:string, "Rule Implementation implementation_key", required: true)
            system(:string, "Rule Implementation system", required: true)
            system_params(:object, "Rule Implementation parameters", required: true)
            rule_id(:integer, "Belongs to rule", required: true)
          end
        end,
      RuleImplementations:
        swagger_schema do
          title("Rule Implementations")
          description("A collection of Rule Implementations")
          type(:array)
          items(Schema.ref(:RuleImplementation))
        end,
      RuleCreateProps:
        swagger_schema do
          properties do
            business_concept_id([:string, nil], "business concept id")
            description(:string, "description")
            goal(:integer, "goal percentage (1-100)")
            minimum(:integer, "minimum goal (1-100)")
            name(:string, "rule name", required: true)
            active(:boolean, "Active/Inactive")
            version(:integer, "Version")
            updated_by(:integer, "Updated by (id)")
            type(:string, "Type")
            type_params(:object, "Type parameters")
          end
        end,
      RuleCreate:
        swagger_schema do
          properties do
            rule(Schema.ref(:RuleCreateProps))
          end
        end,
      RuleUpdate:
        swagger_schema do
          properties do
            rule(Schema.ref(:RuleCreateProps))
          end
        end,
      Rules:
        swagger_schema do
          title("Rules")
          description("A collection of Rules")
          type(:array)
          items(Schema.ref(:Rule))
        end,
      RulesExecuteRequest:
        swagger_schema do
          properties do
            search_params(:object, "Search params")
          end
        end,
      RulesIDs:
        swagger_schema do
          title("Rules IDs")
          description("Rules IDs to execute")
          type(:array)
          items(%{type: :integer})
        end,
      RulesExecuteResponse:
        swagger_schema do
          properties do
            data(Schema.ref(:RulesIDs))
          end
        end,
      RuleResponse:
        swagger_schema do
          properties do
            data(Schema.ref(:Rule))
          end
        end,
      RuleDetailResponse:
        swagger_schema do
          properties do
            data(Schema.ref(:RuleDetail))
          end
        end,
      RulesResponse:
        swagger_schema do
          properties do
            data(Schema.ref(:Rules))
          end
        end
    }
  end

  def rule_implementation_definitions do
    %{
      RuleImplementation:
        swagger_schema do
          title("Rule Implementation")
          description("Rule Implementation entity")

          properties do
            id(:integer, "Rule Implementation unique identifier", required: true)
            implementation_key(:string, "Rule Implementation implementation_key", required: true)
            system(:string, "Rule Implementation system", required: true)
            system_params(:object, "Rule Implementation parameters", required: true)
            rule_id(:integer, "Belongs to rule", required: true)
          end
        end,
      RuleImplementationCreateProps:
        swagger_schema do
          properties do
            description(:string, "Rule Implementation description")
            implementation_key(:string, "Rule Implementation implementation_key", required: true)
            system(:string, "Rule Implementation system", required: true)
            system_params(:object, "Rule Implementation parameters", required: true)
            rule_id(:integer, "belongs to rule", required: true)
          end
        end,
      RuleImplementationCreate:
        swagger_schema do
          properties do
            rule_implementation(Schema.ref(:RuleImplementationCreateProps))
          end
        end,
      RuleImplementationUpdateProps:
        swagger_schema do
          properties do
            implementation_key(:string, "Rule Implementation implementation_key", required: true)
            system(:string, "Rule Implementation system", required: true)
            system_params(:object, "Rule Implementation parameters", required: true)
          end
        end,
      RuleImplementationUpdate:
        swagger_schema do
          properties do
            rule_implementation(Schema.ref(:RuleImplementationUpdateProps))
          end
        end,
      RuleImplementations:
        swagger_schema do
          title("Rule Implementations")
          description("A collection of Rule Implementations")
          type(:array)
          items(Schema.ref(:RuleImplementation))
        end,
      RuleImplementationResponse:
        swagger_schema do
          properties do
            data(Schema.ref(:RuleImplementation))
          end
        end,
      RuleImplementationsResponse:
        swagger_schema do
          properties do
            data(Schema.ref(:RuleImplementations))
          end
        end
    }
  end

  def rule_type_definitions do
    %{
      RuleType:
        swagger_schema do
          title("Rule Type")
          description("Rule Type entity")

          properties do
            id(:integer, "Rule Type unique identifier", required: true)
            name(:string, "Rule Type name", required: true)
            params(:object, "Rule Type parameters", required: true)
          end
        end,
      RuleTypeCreateProps:
        swagger_schema do
          properties do
            name(:string, "Rule Type name", required: true)
            params(:object, "Rule Type parameters", required: true)
          end
        end,
      RuleTypeCreate:
        swagger_schema do
          properties do
            rule_type(Schema.ref(:RuleTypeCreateProps))
          end
        end,
      RuleTypeUpdateProps:
        swagger_schema do
          properties do
            name(:string, "Rule Type name", required: true)
            params(:object, "Rule Type parameters", required: true)
          end
        end,
      RuleTypeUpdate:
        swagger_schema do
          properties do
            rule_type(Schema.ref(:RuleTypeUpdateProps))
          end
        end,
      RuleTypes:
        swagger_schema do
          title("Rule Types")
          description("A collection of Rule Types")
          type(:array)
          items(Schema.ref(:RuleType))
        end,
      RuleTypeResponse:
        swagger_schema do
          properties do
            data(Schema.ref(:RuleType))
          end
        end,
      RuleTypesResponse:
        swagger_schema do
          properties do
            data(Schema.ref(:RuleTypes))
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
              active: [true, false],
              rule_type_id: [1, 2]
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
              business_concept_id: ["1", "2"],
              data_owner: ["user1"]
            }
          })
        end
    }
  end
end
