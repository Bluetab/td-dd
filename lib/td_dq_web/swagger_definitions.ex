defmodule TdDqWeb.SwaggerDefinitions do
  @moduledoc """
   Swagger definitions used by controllers
  """
  import PhoenixSwagger

  def quality_control_definitions do
    %{
      QualityControl: swagger_schema do
        title "Quality Control"
        description "Quality Control entity"
        properties do
          id :integer, "unique identifier", required: true
          business_concept_id :string, "business concept id", required: true
          description :string, "description", required: true
          goal :integer, "goal percentage (1-100)"
          minimum :integer, "minimum goal (1-100)"
          name :string, "quality control name"
          population :string, "population target description"
          priority :string, "Priority (Medium,...)"
          type :string, "type: (Generic, ...)"
          weight :integer, "weight"
          status :string, "status (Default: defined)" #, default: "defined"
          version :integer, "version number"
          updated_by :integer, "updated by user id"
        end
      end,
      QualityControlCreateProps: swagger_schema do
        properties do
          type :string, "type: (Generic, ...)"
          business_concept_id :string, "business concept id", required: true
          name :string, "quality control name"
          description :string, "description", required: true
          weight :integer, "weight"
          priority :string, "Priority (Medium,...)"
          population :string, "population target description"
          goal :integer, "goal percentage (1-100)"
          minimum :integer, "minimum goal (1-100)"
        end
      end,
      QualityControlCreate: swagger_schema do
        properties do
          quality_control Schema.ref(:QualityControlCreateProps)
        end
      end,
      QualityControlUpdate: swagger_schema do
        properties do
          quality_control Schema.ref(:QualityControlCreateProps)
        end
      end,
      QualityControls: swagger_schema do
        title "Quality Controls"
        description "A collection of Quality Controls"
        type :array
        items Schema.ref(:QualityControl)
      end,
      QualityControlResponse: swagger_schema do
        properties do
          data Schema.ref(:QualityControl)
        end
      end,
      QualityControlsResponse: swagger_schema do
        properties do
          data Schema.ref(:QualityControls)
        end
      end
    }
  end

  def quality_control_type_definitions do
    %{
      QualityControlType: swagger_schema do
        title "Quality Control Type"
        description "A Quality Control Type"
        properties do
          type_name :string, "Quality Control type name ", required: true
        end
        example %{
          type_name: "Quality Control Type name",
        }
      end,
      QualityControlTypesResponse: swagger_schema do
        properties do
          data Schema.ref(:QualityControlType)
        end
      end
    }
  end

  def quality_rule_definitions do
    %{
      QualityRule: swagger_schema do
        title "Quality Rule"
        description "Quality Rule entity"
        properties do
          id :integer, "Quality Rule unique identifier", required: true
          quality_control_id :integer, "Belongs to quality control", required: true
          name :string, "Quality Rule name", required: true
          description :string, "Quality Rule description"
          system :string, "Quality Rule system", required: true
          type :string, "Quality Rule type", required: true
          type_params :object, "Quality Rule parameters"
        end
      end,
      QualityRuleCreate: swagger_schema do
        properties do
          quality_control_id :integer, "belongs to quality control", required: true
          name :string, "Quality Rule name", required: true
          description :string, "Quality Rule description"
          system :string, "Quality Rule system", required: true
          type :string, "Quality Rule type", required: true
          type_params :object, "Quality Rule parameters"
        end
      end,
      QualityRuleUpdate: swagger_schema do
        properties do
          name :string, "Quality Rule name", required: true
          description :string, "Quality Rule description"
          system :string, "Quality Rule system", required: true
          type :string, "Quality Rule type", required: true
          type_params :object, "Quality Rule parameters"
        end
      end,
      QualityRules: swagger_schema do
        title "Quality Rules"
        description "A collection of Quality Rules"
        type :array
        items Schema.ref(:QualityRule)
      end,
      QualityRuleResponse: swagger_schema do
        properties do
          data Schema.ref(:QualityRule)
        end
      end,
      QualityRulesResponse: swagger_schema do
        properties do
          data Schema.ref(:QualityRules)
        end
      end
    }
  end

  def quality_control_type_parameters_definitions do
    %{
      QualityControlTypeParam: swagger_schema do
        properties do
          name :string, "Quality control type parameter name"
          type :string, "Quality control type parameter type"
        end
      end,
      QualityControlTypeParamsResponse: swagger_schema do
        properties do
          data Schema.ref(:QualityControlTypeParam)
        end
      end
    }
  end

end
