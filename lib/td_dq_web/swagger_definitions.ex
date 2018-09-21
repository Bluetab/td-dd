defmodule TdDqWeb.SwaggerDefinitions do
  @moduledoc """
   Swagger definitions used by controllers
  """
  import PhoenixSwagger

  def rule_definitions do
    %{
      Rule: swagger_schema do
        title "Rule"
        description "Rule entity"
        properties do
          id :integer, "unique identifier", required: true
          business_concept_id :string, "business concept id", required: true
          description :string, "description", required: true
          goal :integer, "goal percentage (1-100)"
          minimum :integer, "minimum goal (1-100)"
          name :string, "rule name"
          population :string, "population target description"
          priority :string, "Priority (Medium,...)"
          weight :integer, "weight"
          status :string, "status (Default: defined)" #, default: "defined"
          version :integer, "version number"
          updated_by :integer, "updated by user id"
          principle :object, "rule principle"
          type_params :object, "rule type_params"
          rule_type_id :integer, "Belongs to rule type", required: true
          tag :object
        end
      end,
      RuleImplementation: swagger_schema do
        title "Rule Implementation"
        description "Rule Implementation entity"
        properties do
          id :integer, "Rule Implementation unique identifier", required: true
          description :string, "Rule Implementation description"
          implementation_key :string, "Rule Implementation implementation_key", required: true
          system :string, "Rule Implementation system", required: true
          system_params :object, "Rule Implementation parameters", required: true
          tag :object, "Rule Implementation tag"
          rule_id :integer, "Belongs to rule", required: true
        end
      end,
      RuleImplementations: swagger_schema do
        title "Rule Implementations"
        description "A collection of Rule Implementations"
        type :array
        items Schema.ref(:RuleImplementation)
      end,
      RuleCreateProps: swagger_schema do
        properties do
          business_concept_id :string, "business concept id", required: true
          description :string, "description"
          goal :integer, "goal percentage (1-100)"
          minimum :integer, "minimum goal (1-100)"
          name :string, "rule name", required: true
          population :string, "population target description"
          priority :string, "Priority (Medium,...)"
          weight :integer, "weight"
          status :string, "weight"
          version :integer, "weight"
          updated_by :integer, "weight"
          principle :object, "rule principle"
          type :string, "weight"
          type_params :object, "weight"
          tag :object, "weight"
        end
      end,
      RuleCreate: swagger_schema do
        properties do
          rule Schema.ref(:RuleCreateProps)
        end
      end,
      RuleUpdate: swagger_schema do
        properties do
          rule Schema.ref(:RuleCreateProps)
        end
      end,
      Rules: swagger_schema do
        title "Rules"
        description "A collection of Rules"
        type :array
        items Schema.ref(:Rule)
      end,
      RuleResponse: swagger_schema do
        properties do
          data Schema.ref(:Rule)
        end
      end,
      RulesResponse: swagger_schema do
        properties do
          data Schema.ref(:Rules)
        end
      end
    }
  end

  def rule_implementation_definitions do
    %{
      RuleImplementation: swagger_schema do
        title "Rule Implementation"
        description "Rule Implementation entity"
        properties do
          id :integer, "Rule Implementation unique identifier", required: true
          description :string, "Rule Implementation description"
          implementation_key :string, "Rule Implementation implementation_key", required: true
          system :string, "Rule Implementation system", required: true
          system_params :object, "Rule Implementation parameters", required: true
          tag :object, "Rule Implementation tag"
          rule_id :integer, "Belongs to rule", required: true
        end
      end,
      RuleImplementationCreateProps: swagger_schema do
        properties do
          description :string, "Rule Implementation description"
          implementation_key :string, "Rule Implementation implementation_key", required: true
          system :string, "Rule Implementation system", required: true
          system_params :object, "Rule Implementation parameters", required: true
          tag :object, "Rule Implementation tag"
          rule_id :integer, "belongs to rule", required: true
        end
      end,
      RuleImplementationCreate: swagger_schema do
        properties do
          rule_implementation Schema.ref(:RuleImplementationCreateProps)
        end
      end,
      RuleImplementationUpdateProps: swagger_schema do
        properties do
          description :string, "Rule Implementation description"
          implementation_key :string, "Rule Implementation implementation_key", required: true
          system :string, "Rule Implementation system", required: true
          system_params :object, "Rule Implementation parameters", required: true
          tag :object, "Rule Implementation tag"
        end
      end,
      RuleImplementationUpdate: swagger_schema do
        properties do
          rule_implementation Schema.ref(:RuleImplementationUpdateProps)
        end
      end,
      RuleImplementations: swagger_schema do
        title "Rule Implementations"
        description "A collection of Rule Implementations"
        type :array
        items Schema.ref(:RuleImplementation)
      end,
      RuleImplementationResponse: swagger_schema do
        properties do
          data Schema.ref(:RuleImplementation)
        end
      end,
      RuleImplementationsResponse: swagger_schema do
        properties do
          data Schema.ref(:RuleImplementations)
        end
      end
    }
  end

  def rule_type_definitions do
    %{
      RuleType: swagger_schema do
        title "Rule Type"
        description "Rule Type entity"
        properties do
          id :integer, "Rule Type unique identifier", required: true
          name :string, "Rule Type name", required: true
          params :object, "Rule Type parameters", required: true
        end
      end,
      RuleTypeCreateProps: swagger_schema do
        properties do
          name :string, "Rule Type name", required: true
          params :object, "Rule Type parameters", required: true
        end
      end,
      RuleTypeCreate: swagger_schema do
        properties do
          rule_type Schema.ref(:RuleTypeCreateProps)
        end
      end,
      RuleTypeUpdateProps: swagger_schema do
        properties do
          name :string, "Rule Type name", required: true
          params :object, "Rule Type parameters", required: true
        end
      end,
      RuleTypeUpdate: swagger_schema do
        properties do
          rule_type Schema.ref(:RuleTypeUpdateProps)
        end
      end,
      RuleTypes: swagger_schema do
        title "Rule Types"
        description "A collection of Rule Types"
        type :array
        items Schema.ref(:RuleType)
      end,
      RuleTypeResponse: swagger_schema do
        properties do
          data Schema.ref(:RuleType)
        end
      end,
      RuleTypesResponse: swagger_schema do
        properties do
          data Schema.ref(:RuleTypes)
        end
      end
    }
  end
end
