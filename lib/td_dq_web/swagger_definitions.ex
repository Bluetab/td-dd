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
            business_concept_id([:integer, nil], "business concept id")
            description(:object, "Description")
            goal(:integer, "goal percentage (1-100)")
            minimum(:integer, "minimum goal (1-100)")
            name(:string, "rule name")
            active(:boolean, "active (Default: false)")
            version(:integer, "version number")
            updated_by(:integer, "updated by user id")
          end
        end,
      Implementation:
        swagger_schema do
          title("Rule Implementation")
          description("Rule Implementation entity")

          properties do
            id(:integer, "Rule Implementation unique identifier", required: true)
            implementation_key(:string, "Rule Implementation implementation_key", required: true)
            executable(:boolean, "Rule Implementation executable property")
            rule_id([:integer, nil], "Belongs to rule")
            dataset(Schema.ref(:DatasetArray), required: false)
            population(Schema.ref(:ConditionArray), required: false)
            validations(Schema.ref(:ConditionArray), required: false)

            raw_content(Schema.ref(:RawContent), "Raw content for raw implementation type",
              required: false
            )
          end
        end,
      DatasetArray:
        swagger_schema do
          type(:array)
          items(Schema.ref(:Dataset))
        end,
      ConditionArray:
        swagger_schema do
          type(:array)
          items(Schema.ref(:Condition))
        end,
      Condition:
        swagger_schema do
          properties do
            value(:array, "Values", required: true)
            operator(Schema.ref(:Operator))
            structure(Schema.ref(:Structure))
          end
        end,
      Dataset:
        swagger_schema do
          properties do
            structure(Schema.ref(:Structure))
            join_type([:string, :null])
          end
        end,
      Structure:
        swagger_schema do
          properties do
            id(:integer, "structure id", required: true)
          end
        end,
      Operator:
        swagger_schema do
          properties do
            name(:string)
            group(:string)
            value_type(:string)
          end
        end,
      Implementations:
        swagger_schema do
          title("Rule Implementations")
          description("A collection of Rule Implementations")
          type(:array)
          items(Schema.ref(:Implementation))
        end,
      RuleCreateProps:
        swagger_schema do
          properties do
            business_concept_id([:integer, nil], "business concept id")
            domain_id(:integer, "Domain id", required: true)
            description(:object, "Description")
            goal(:integer, "goal percentage (1-100)")
            minimum(:integer, "minimum goal (1-100)")
            name(:string, "rule name", required: true)
            active(:boolean, "Active/Inactive")
            version(:integer, "Version")
            updated_by(:integer, "Updated by (id)")
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
      RuleResponse:
        swagger_schema do
          properties do
            data(Schema.ref(:Rule))
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

  def implementation_definitions do
    %{
      Implementation:
        swagger_schema do
          title("Rule Implementation")
          description("Rule Implementation entity")

          properties do
            id(:integer, "Rule Implementation unique identifier", required: true)
            implementation_key(:string, "Rule Implementation implementation_key", required: true)

            implementation_type(:string, "Rule implementation type (default or raw)",
              required: true
            )

            rule_id([:integer, nil], "Belongs to rule")
            dataset(Schema.ref(:DatasetArray), "Dataset", required: false)
            population(Schema.ref(:ConditionArray))
            validations(Schema.ref(:ConditionArray), "Validations", required: false)

            raw_content(Schema.ref(:RawContent), "Raw content for raw implementation type",
              required: false
            )
          end
        end,
      DatasetArray:
        swagger_schema do
          type(:array)
          items(Schema.ref(:Dataset))
        end,
      ConditionArray:
        swagger_schema do
          type(:array)
          items(Schema.ref(:Condition))
        end,
      Condition:
        swagger_schema do
          properties do
            value(:array, "Values", required: true)
            operator(Schema.ref(:Operator), "Operator", required: true)
            structure(Schema.ref(:Structure), "Structure", required: true)
          end
        end,
      Dataset:
        swagger_schema do
          properties do
            structure(Schema.ref(:Structure), "dataset structure", required: true)
            join_type([:string, :null])
          end
        end,
      Structure:
        swagger_schema do
          properties do
            id(:integer, "structure id", required: true)
          end
        end,
      Operator:
        swagger_schema do
          properties do
            name(:string, "Operator name", required: true)
            value_type(:string)
          end
        end,
      RawContent:
        swagger_schema do
          properties do
            dataset(:string, "dataset raw text", required: true)
            source_id([:integer], "source id", required: true)
            source([:object], "source")
            database([:string, nil], "source database", required: false)
            population([:string, nil], "population raw text", required: false)
            validations(:string, "validations raw text", required: true)
          end
        end,
      ImplementationCreateProps:
        swagger_schema do
          properties do
            description(:string, "Rule Implementation description")
            implementation_key(:string, "Rule Implementation implementation_key", required: true)
            rule_id([:integer, nil], "Belongs to rule")
          end
        end,
      ImplementationCreate:
        swagger_schema do
          properties do
            rule_implementation(Schema.ref(:ImplementationCreateProps))
          end
        end,
      ImplementationUpdateProps:
        swagger_schema do
          properties do
            implementation_key(:string, "Rule Implementation implementation_key", required: true)
          end
        end,
      ImplementationUpdate:
        swagger_schema do
          properties do
            rule_implementation(Schema.ref(:ImplementationUpdateProps))
          end
        end,
      Implementations:
        swagger_schema do
          title("Rule Implementations")
          description("A collection of Rule Implementations")
          type(:array)
          items(Schema.ref(:Implementation))
        end,
      ImplementationResponse:
        swagger_schema do
          properties do
            data(Schema.ref(:Implementation))
          end
        end,
      ImplementationsResponse:
        swagger_schema do
          properties do
            data(Schema.ref(:Implementations))
          end
        end,
      ImplementationsSearchFilters:
        swagger_schema do
          properties do
            structure_id(:integer, "structure id", required: false)
            filters(:object, "Filters", required: false)
          end

          example(%{
            filters: %{
              rule: %{active: true},
              implementation_key: "ri1",
              structure: %{metadata: %{alias_: "source_alias"}}
            }
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
              active: [true, false]
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

  def execution_group_swagger_definitions do
    %{
      ExecutionGroup:
        swagger_schema do
          title("Execution Group")
          description("An group of rule implementations")

          properties do
            executions(Schema.ref(:Executions))
            id(:integer, "Execution Group unique identifier", required: true)
            inserted_at(:string, "insert timestamp")
          end
        end,
      Executions:
        swagger_schema do
          title("Executions")
          description("A collection of Executions")
          type(:array)
          items(Schema.ref(:Execution))
        end,
      Execution:
        swagger_schema do
          properties do
            id(:integer, "Execution unique identifier", required: true)
            inserted_at(:string, "insert timestamp")
            _embedded(Schema.ref(:ExecutionEmbeddings))
          end
        end,
      ExecutionEmbeddings:
        swagger_schema do
          properties do
            implementation(Schema.ref(:EmbeddedImplementation))
            result(Schema.ref(:EmbeddedRuleResult))
          end
        end,
      EmbeddedImplementation:
        swagger_schema do
          properties do
            id(:integer, "Rule implementation unique identifier", required: true)
            implementation_key(:string, "Rule implementation key", required: true)
          end
        end,
      ExecutionGroups:
        swagger_schema do
          title("Execution Groups")
          description("A collection of Execution Groups")
          type(:array)
          items(Schema.ref(:ExecutionGroup))
        end,
      ExecutionGroupResponse:
        swagger_schema do
          properties do
            data(Schema.ref(:ExecutionGroup))
          end
        end,
      ExecutionGroupsResponse:
        swagger_schema do
          properties do
            data(Schema.ref(:ExecutionGroups))
          end
        end,
      ExecutionsResponse:
        swagger_schema do
          properties do
            data(Schema.ref(:Executions))
          end
        end,
      EmbeddedRuleResult:
        swagger_schema do
          properties do
            id(:integer, "Rule result identifier", required: true)
            implementation_key(:string, "Implementation key", required: true)
            date(:string, "Execution date", required: true)
            errors(:string)
            records(:string)
            result(:string)
          end
        end
    }
  end

  def rule_result_swagger_definitions do
    %{
      RuleResult:
        swagger_schema do
          title("Rule Result")
          description("The result of a quality rule execution")

          properties do
            id(:integer, "Rule Result unique identifier", required: true)
            date(:string, "datetime")
            result(:string, "The result (decimal)")
            errors(:integer, "The error count")
            records(:integer, "The record count")
            params(:object, "Execution parameters")
            inserted_at(:string, "insert timestamp")
            updated_at(:string, "update timestamp")
          end
        end,
      RuleResultCreate:
        swagger_schema do
          properties do
            rule_result(Schema.ref(:RuleResult))
          end
        end,
      RuleResultResponse:
        swagger_schema do
          properties do
            data(Schema.ref(:RuleResult))
          end
        end
    }
  end

  def segment_results_swagger_definitions do
    %{
      SegmentResult:
        swagger_schema do
          title("Segment Result")
          description("The result of a quality segment rule execution")

          properties do
            id(:integer, "Segment Result unique identifier", required: true)
            parent_id(:integer, "Parent rule Result id", required: true)
            date(:string, "datetime")
            result(:string, "The result (decimal)")
            errors(:integer, "The error count")
            records(:integer, "The record count")
            params(:object, "Execution parameters")
            inserted_at(:string, "insert timestamp")
            updated_at(:string, "update timestamp")
          end
        end,
      SegmentResultResponse:
        swagger_schema do
          properties do
            items(Schema.ref(:SegmentResult))
          end
        end
    }
  end

  def quality_event_swagger_definitions do
    %{
      QualityEvent:
        swagger_schema do
          title("Quality Event")
          description("Representation of event")

          properties do
            id(:integer, "Event Id", required: true)
            execution_id(:integer, "Execution Id", required: true)
            inserted_at(:string, "Event insertion date")
            type([:string, :null], "Event type")
            message([:string, :null], "Event message")
          end
        end,
      QualityEventResponse:
        swagger_schema do
          properties do
            data(Schema.ref(:QualityEvent))
          end
        end,
      EmbeddedQualityEvents:
        swagger_schema do
          title("Quality Events")
          description("A collection of events")
          type(:array)
          items(Schema.ref(:QualityEvent))
        end
    }
  end

  def remediation_swagger_definitions do
    %{
      Remediation:
        swagger_schema do
          title("Remediation plan")
          description("Rule result remediation plan")

          properties do
            id(:integer, "Remediation unique identifier", required: true)
            df_name(:string, "Remediation template name", required: true)
            df_content(:object, "Remediation template content", required: true)
          end
        end,
      RemediationCreate:
        swagger_schema do
          properties do
            remediation(
              Schema.new do
                properties do
                  df_name(:string, "Remediation template name", required: true)
                  df_content(:object, "Remediation template content", required: true)
                end
              end
            )
          end
        end,
      RemediationUpdate:
        swagger_schema do
          properties do
            remediation(
              Schema.new do
                properties do
                  df_name(:string, "Remediation template name")
                  df_content(:object, "Remediation template content")
                end
              end
            )
          end
        end,
      RemediationResponse:
        swagger_schema do
          properties do
            data(Schema.ref(:Remediation))
          end
        end
    }
  end
end
