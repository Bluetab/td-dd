Feature: Quality Rules
  A Quality rule depends always on the existance of a quality control and will
  be related with a quality controll

  Scenario: Create a new Quality rule
    Given user "my-user" logged in the application
    And a existing Quality Control with following data:
      | Field               | Value                                                                                  |
      | Business Concept ID | MYID_333                                                                               |
      | Name                | Field's Quality Control                                                                |
      | Description         | In order to measure quality of this field we will check whether its values are correct |
      | Weight              | 50                                                                                     |
      | Priority            | Medium                                                                                 |
      | Population          | All clients who are older than 18                                                      |
      | Goal                | 98                                                                                     |
      | Minimum             | 80                                                                                     |
      | Type                | Integer Values Range                                                                   |
      | Type Params         | %-{ "Minimum Value": 18, "Maximum Value": 50 }                                         |
    And a existing Quality Rule Type with name "Integer Values Range" and the following parameters:
      | Params        | Name                | Type   |
      | Type Params   | Minimum Value       | int    |
      | Type Params   | Maximum Value       | int    |
      | System Params | Table               | string |
      | System Params | Field               | string |
    When "my-user" tries to create a Quality Rule associated to Quality Control "Field's Quality Control" with following data:
      | Field               | Value                                                                                  |
      | Type                | Integer Values Range                                                                   |
      | System              | Oracle                                                                                 |
      | Name                | Age between 18 and 50                                                                  |
      | Description         | My Generic Quality Control Rule                                                        |
      | System Params       | %-{ "Table": "Clients", "Field": "Age" }                                               |
    Then the system returns a result with code "Created"
    And "my-user" is able to view a Quality Rule named "Age between 18 and 50" with with following data:
      | Field               | Value                                                                                  |
      | Type                | Integer Values Range                                                                   |
      | System              | Oracle                                                                                 |
      | Name                | Age between 18 and 50                                                                  |
      | Description         | My Generic Quality Control Rule                                                        |
      | System Params       | %-{ "Table": "Clients", "Field": "Age" }                                               |

  Scenario: Create a new Quality rule whithout an associated Quality Rule Type
    Given user "my-user" logged in the application
    And a existing Quality Control with following data:
      | Field               | Value                                                                                  |
      | Business Concept ID | MYID_333                                                                               |
      | Name                | Field's Quality Control                                                                |
      | Description         | In order to measure quality of this field we will check whether its values are correct |
      | Weight              | 50                                                                                     |
      | Priority            | Medium                                                                                 |
      | Population          | All clients who are older than 18                                                      |
      | Goal                | 98                                                                                     |
      | Minimum             | 80                                                                                     |
      | Type                | Integer Values Range                                                                   |
      | Type Params         | %-{ "Minimum Value": 18, "Maximum Value": 50 }                                         |
    When "my-user" tries to create a Quality Rule associated to Quality Control "Field's Quality Control" without an existing Quality Rule type and the following data:
      | Field               | Value                                                                                  |
      | System              | Oracle                                                                                 |
      | Name                | Age between 18 and 50                                                                  |
      | Description         | My Generic Quality Control Rule                                                        |
      | System Params       | %-{ "Table": "Clients", "Field": "Age" }                                               |
    Then the system returns a result with code "Unprocessable Entity"

  Scenario: Create a new Quality rule which does not match with its Quality Rule Type params
    Given user "my-user" logged in the application
    And a existing Quality Control with following data:
      | Field               | Value                                                                                  |
      | Business Concept ID | MYID_333                                                                               |
      | Name                | Field's Quality Control                                                                |
      | Description         | In order to measure quality of this field we will check whether its values are correct |
      | Weight              | 50                                                                                     |
      | Priority            | Medium                                                                                 |
      | Population          | All clients who are older than 18                                                      |
      | Goal                | 98                                                                                     |
      | Minimum             | 80                                                                                     |
      | Type                | Integer Values Range                                                                   |
      | Type Params         | %-{ "Minimum Value": 18, "Maximum Value": 50 }                                         |
    And a existing Quality Rule Type with name "Integer Values Range" and the following parameters:
      | Params        | Name                | Type   |
      | Type Params   | Minimum Value       | int    |
      | Type Params   | Maximum Value       | int    |
      | System Params | Table               | string |
      | System Params | Field               | string |
    When "my-user" tries to create a Quality Rule associated to Quality Control "Field's Quality Control" with following data:
      | Field               | Value                                                                                  |
      | Type                | Integer Values Range                                                                   |
      | System              | Oracle                                                                                 |
      | Name                | Age between 18 and 50                                                                  |
      | Description         | My Generic Quality Control Rule                                                        |
      | System Params       | %-{ "Table": "Clients", "Field": "Age", "Type": "I made it up" }                       |
    Then the system returns a result with code "Unprocessable Entity"
