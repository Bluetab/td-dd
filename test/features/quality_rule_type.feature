Feature: Quality Rule Type
  A quality rule type will be used by a quality control and a quality rule
  
  Scenario: Create a new quality rule type
    Given user "my-user" logged in the application
    When "my-user" tries to create a Rule named "Integer Values Range" with following data:
      | Params                                                                                                        |
      | {"type_params": [{"name": "Minimum Value", "type": "integer"}, {"name": "Maximum Value", "type": "integer"}]} |
      | {"system_params": [{"name": "Table", "type": "string"}, {"name": "Field", "type": "string"}]}                 |
   Then the system returns a result with code "Created"
   And "my-user" is able to view rule type named "Integer Values Range" with following data:
      | Params                                                                                                        |
      | {"type_params": [{"name": "Minimum Value", "type": "integer"}, {"name": "Maximum Value", "type": "integer"}]} |
      | {"system_params": [{"name": "Table", "type": "string"}, {"name": "Field", "type": "string"}]}                 |
  
  Scenario: Create a new quality rule type whith invalid params
    Given user "my-user" logged in the application
    When "my-user" tries to create a Rule named "Integer Values Range" with following data:
      | Params                                                   |
      | {"Invalid Params": [{"name": "Value", "type": "integer"}]} |
   Then the system returns a result with code "Unprocessable Entity"

  Scenario: Create a new quality rule type whith invalid number of params
    Given user "my-user" logged in the application
    When "my-user" tries to create a Rule named "Integer Values Range" with following data:
      | Params                                                                                                        |
      | {"type_params": [{"name": "Minimum Value", "type": "integer"}, {"name": "Maximum Value", "type": "integer"}]} |
      | {"system_params": [{"name": "Table", "type": "string"}, {"name": "Field", "type": "string"}]}                 |
      | {"Invalid Params": [{"name": "Value", "type": "integer"}]}                                                    |
   Then the system returns a result with code "Unprocessable Entity"
  
  Scenario: Create a new quality rule without params
    Given user "my-user" logged in the application
    When "my-user" tries to create a Rule named "Integer Values Range" with following data:
      | Params |
      | {}     |
   Then the system returns a result with code "Created"