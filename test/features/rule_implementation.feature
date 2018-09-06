Feature: Quality Rules
  A Rule depends always on the existance of a quality control and will
  be related with a quality rule type

  Scenario: Create a new Rule
    Given user "my-user" logged in the application
    And a existing Quality Rule Type with name "Integer Values Range" and the following parameters:
      | Params                                                                                                        |
      | {"type_params": [{"name": "Minimum Value", "type": "integer"}, {"name": "Maximum Value", "type": "integer"}]} |
      | {"system_params": [{"name": "Table", "type": "string"}, {"name": "Field", "type": "string"}]}                 |
    And a existing Rule with following data:
      | Field               | Value                                                                                  |
      | Business Concept ID | MYID_333                                                                               |
      | Name                | Field's Rule                                                                |
      | Description         | In order to measure quality of this field we will check whether its values are correct |
      | Weight              | 50                                                                                     |
      | Priority            | Medium                                                                                 |
      | Population          | All clients who are older than 18                                                      |
      | Goal                | 98                                                                                     |
      | Minimum             | 80                                                                                     |
      | Type                | Integer Values Range                                                                   |
      | Type Params         | %-{ "Minimum Value": 18, "Maximum Value": 50 }                                         |
    When "my-user" tries to create a Quality Rule associated to Rule "Field's Rule" with following data:
      | Field               | Value                                                                                  |
      | Type                | Integer Values Range                                                                   |
      | System              | Oracle                                                                                 |
      | Name                | Age between 18 and 50                                                                  |
      | Description         | My Generic Rule Rule                                                        |
      | System Params       | %-{ "Table": "Clients", "Field": "Age" }                                               |
    Then the system returns a result with code "Created"
    And "my-user" is able to view a Quality Rule named "Age between 18 and 50" with following data:
      | Field               | Value                                                                                  |
      | Type                | Integer Values Range                                                                   |
      | System              | Oracle                                                                                 |
      | Name                | Age between 18 and 50                                                                  |
      | Description         | My Generic Rule Rule                                                        |
      | System Params       | %-{ "Table": "Clients", "Field": "Age" }                                               |

  Scenario: Create a new Rule whithout an associated Quality Rule Type
    Given user "my-user" logged in the application
    And a existing Quality Rule Type with name "Integer Values Range" and the following parameters:
      | Params                                                                                                        |
      | {"type_params": [{"name": "Minimum Value", "type": "integer"}, {"name": "Maximum Value", "type": "integer"}]} |
      | {"system_params": [{"name": "Table", "type": "string"}, {"name": "Field", "type": "string"}]}                 |
    And a existing Rule with following data:
      | Field               | Value                                                                                  |
      | Business Concept ID | MYID_333                                                                               |
      | Name                | Field's Rule                                                                |
      | Description         | In order to measure quality of this field we will check whether its values are correct |
      | Weight              | 50                                                                                     |
      | Priority            | Medium                                                                                 |
      | Population          | All clients who are older than 18                                                      |
      | Goal                | 98                                                                                     |
      | Minimum             | 80                                                                                     |
      | Type                | Integer Values Range                                                                   |
      | Type Params         | %-{ "Minimum Value": 18, "Maximum Value": 50 }                                         |
    When "my-user" tries to create a Quality Rule associated to Rule "Field's Rule" without an existing Quality Rule type and the following data:
      | Field               | Value                                                                                  |
      | System              | Oracle                                                                                 |
      | Name                | Age between 18 and 50                                                                  |
      | Description         | My Generic Rule Rule                                                        |
      | System Params       | %-{ "Table": "Clients", "Field": "Age" }                                               |
    Then the system returns a result with code "Unprocessable Entity"

  Scenario: Create a new Rule which does not ths same numer of params as its Quality Rule Type
    Given user "my-user" logged in the application
    And a existing Quality Rule Type with name "Integer Values Range" and the following parameters:
      | Params                                                                                                        |
      | {"type_params": [{"name": "Minimum Value", "type": "integer"}, {"name": "Maximum Value", "type": "integer"}]} |
      | {"system_params": [{"name": "Table", "type": "string"}, {"name": "Field", "type": "string"}]}                 |
    And a existing Rule with following data:
      | Field               | Value                                                                                  |
      | Business Concept ID | MYID_333                                                                               |
      | Name                | Field's Rule                                                                |
      | Description         | In order to measure quality of this field we will check whether its values are correct |
      | Weight              | 50                                                                                     |
      | Priority            | Medium                                                                                 |
      | Population          | All clients who are older than 18                                                      |
      | Goal                | 98                                                                                     |
      | Minimum             | 80                                                                                     |
      | Type                | Integer Values Range                                                                   |
      | Type Params         | %-{ "Minimum Value": 18, "Maximum Value": 50 }                                         |
    When "my-user" tries to create a Quality Rule associated to Rule "Field's Rule" with following data:
      | Field               | Value                                                                                  |
      | Type                | Integer Values Range                                                                   |
      | System              | Oracle                                                                                 |
      | Name                | Age between 18 and 50                                                                  |
      | Description         | My Generic Rule Rule                                                        |
      | System Params       | %-{ "Table": "Clients", "Field": "Age", "Type": "I made it up" }                       |
    Then the system returns a result with code "Unprocessable Entity"

  Scenario: Create a new Rule with a different System Param type to its Quality Rule Type
    Given user "my-user" logged in the application
    And a existing Quality Rule Type with name "Integer Values Range" and the following parameters:
      | Params                                                                                                        |
      | {"type_params": [{"name": "Minimum Value", "type": "integer"}, {"name": "Maximum Value", "type": "integer"}]} |
      | {"system_params": [{"name": "Table", "type": "string"}, {"name": "Field", "type": "string"}]}                 |
    And a existing Rule with following data:
      | Field               | Value                                                                                  |
      | Business Concept ID | MYID_333                                                                               |
      | Name                | Field's Rule                                                                |
      | Description         | In order to measure quality of this field we will check whether its values are correct |
      | Weight              | 50                                                                                     |
      | Priority            | Medium                                                                                 |
      | Population          | All clients who are older than 18                                                      |
      | Goal                | 98                                                                                     |
      | Minimum             | 80                                                                                     |
      | Type                | Integer Values Range                                                                   |
      | Type Params         | %-{ "Minimum Value": 18, "Maximum Value": 50 }                                         |
    When "my-user" tries to create a Quality Rule associated to Rule "Field's Rule" with following data:
      | Field               | Value                                                                                  |
      | Type                | Integer Values Range                                                                   |
      | System              | Oracle                                                                                 |
      | Name                | Age between 18 and 50                                                                  |
      | Description         | My Generic Rule Rule                                                        |
      | System Params       | %-{ "Table": "Clients", "Field": 0 }                                                   |
    Then the system returns a result with code "Unprocessable Entity"

  Scenario: Create a new Rule which params do not match with its Quality Rule Type params
    Given user "my-user" logged in the application
    And a existing Quality Rule Type with name "Integer Values Range" and the following parameters:
      | Params                                                                                                        |
      | {"type_params": [{"name": "Minimum Value", "type": "integer"}, {"name": "Maximum Value", "type": "integer"}]} |
      | {"system_params": [{"name": "Table", "type": "string"}, {"name": "Field", "type": "string"}]}                 |
    And a existing Rule with following data:
      | Field               | Value                                                                                  |
      | Business Concept ID | MYID_333                                                                               |
      | Name                | Field's Rule                                                                |
      | Description         | In order to measure quality of this field we will check whether its values are correct |
      | Weight              | 50                                                                                     |
      | Priority            | Medium                                                                                 |
      | Population          | All clients who are older than 18                                                      |
      | Goal                | 98                                                                                     |
      | Minimum             | 80                                                                                     |
      | Type                | Integer Values Range                                                                   |
      | Type Params         | %-{ "Minimum Value": 18, "Maximum Value": 50 }                                         |
    When "my-user" tries to create a Quality Rule associated to Rule "Field's Rule" with following data:
      | Field               | Value                                                                                  |
      | Type                | Integer Values Range                                                                   |
      | System              | Oracle                                                                                 |
      | Name                | Age between 18 and 50                                                                  |
      | Description         | My Generic Rule Rule                                                        |
      | System Params       | %-{ "Table": "Clients", "Wrong Field": "Age" }                                         |
    Then the system returns a result with code "Unprocessable Entity"
