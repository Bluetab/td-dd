Feature: Rule Implementations
  A rule implementation depends always on the existance of a rule and will
  be related with a rule type

  Scenario: Create a new Rule Implementation
    Given user "my-user" logged in the application
    And a existing Rule Type with name "Integer Values Range" and the following parameters:
      | Params                                                                                                        |
      | {"type_params": [{"name": "Minimum Value", "type": "integer"}, {"name": "Maximum Value", "type": "integer"}]} |
      | {"system_params": [{"name": "Table", "type": "string"}, {"name": "Field", "type": "string"}]}                 |
    And a existing Rule of type "Integer Values Range" with following data:
      | Field               | Value                                                                                  |
      | Business Concept ID | MYID_333                                                                               |
      | Name                | Field's Rule                                                                           |
      | Description         | In order to measure quality of this field we will check whether its values are correct |
      | Weight              | 50                                                                                     |
      | Priority            | Medium                                                                                 |
      | Population          | All clients who are older than 18                                                      |
      | Goal                | 98                                                                                     |
      | Minimum             | 80                                                                                     |
      | Type Params         | %-{ "Minimum Value": 18, "Maximum Value": 50 }                                         |
    When "my-user" tries to create a Rule Implementation associated to Rule "Field's Rule" with following data:
      | Field               | Value                                                                                  |
      | System              | Oracle                                                                                 |
      | Implementation key  | ri0001                                                                                 |
      | Description         | My Generic Rule Rule                                                                   |
      | System Params       | %-{ "Table": "Clients", "Field": "Age" }                                               |
    Then the system returns a result with code "Created"
    And "my-user" is able to view a Rule Implementation named "ri0001" with following data:
      | Field               | Value                                                                                  |
      | System              | Oracle                                                                                 |
      | Implementation key  | ri0001                                                                                 |
      | Description         | My Generic Rule Rule                                                                   |
      | System Params       | %-{ "Table": "Clients", "Field": "Age" }                                               |
    When "my-user" tries to create a Rule Implementation associated to Rule "Field's Rule" with following data:
      | Field               | Value                                                                                  |
      | System              | Oracle                                                                                 |
      | Implementation key  | ri 0001                                                                                |
      | Description         | My Generic Rule Rule                                                                   |
      | System Params       | %-{ "Table": "Clients", "Field": "Age" }                                               |
    Then the system returns a result with code "Unprocessable Entity"
    And the system returns an error with name "rule.implementation.error.implementation_key.invalid"
    When "my-user" tries to create a Rule Implementation associated to Rule "Field's Rule" with following data:
    | Field               | Value                                                                                  |
    | System              | Oracle                                                                                 |
    | Implementation key  |                                                                                        |
    | Description         | My Generic Rule Rule                                                                   |
    | System Params       | %-{ "Table": "Clients", "Field": "Age" }                                               |
    Then the system returns a result with code "Created"

  Scenario: Create a new Rule Implementation with an existing implementation key
    Given user "my-user" logged in the application
    And a existing Rule Type with name "Integer Values Range" and the following parameters:
      | Params                                                                                                        |
      | {"type_params": [{"name": "Minimum Value", "type": "integer"}, {"name": "Maximum Value", "type": "integer"}]} |
      | {"system_params": [{"name": "Table", "type": "string"}, {"name": "Field", "type": "string"}]}                 |
    And a existing Rule of type "Integer Values Range" with following data:
      | Field               | Value                                                                                  |
      | Business Concept ID | MYID_333                                                                               |
      | Name                | Field's Rule                                                                           |
      | Description         | In order to measure quality of this field we will check whether its values are correct |
      | Weight              | 50                                                                                     |
      | Priority            | Medium                                                                                 |
      | Population          | All clients who are older than 18                                                      |
      | Goal                | 98                                                                                     |
      | Minimum             | 80                                                                                     |
      | Type Params         | %-{ "Minimum Value": 18, "Maximum Value": 50 }                                         |
    And a existing Rule Implementation associated to Rule "Field's Rule" with following data:
      | Field               | Value                                                                                  |
      | System              | Oracle                                                                                 |
      | Implementation key  | ri0001                                                                                 |
      | Description         | My Generic Rule Rule                                                                   |
      | System Params       | %-{ "Table": "Clients", "Field": "Age" }                                               |
    When "my-user" tries to create a Rule Implementation associated to Rule "Field's Rule" with following data:
      | Field               | Value                                                                                  |
      | System              | Oracle                                                                                 |
      | Implementation key  | ri0001                                                                                |
      | Description         | My Generic Rule Rule                                                                   |
      | System Params       | %-{ "Table": "Clients", "Field": "Age" }                                               |
    Then the system returns a result with code "Unprocessable Entity"
    And the system returns an error with name "rule.implementation.error.implementation_key.not_available"
