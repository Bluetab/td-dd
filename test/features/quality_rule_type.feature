Feature: Quality Rule Type
  A quality rule type will be used by a quality control and a quality rule
  
  Scenario: Create a new quality rule type
    Given user "my-user" logged in the application
    When "my-user" tries to create a Rule named "Integer Values Range" with following data:
      | Params        | Name                | Type       |
      | Type Params   | Minimum Value       | integer    |
      | Type Params   | Maximum Value       | integer    |
      | System Params | Table               | string     |
      | System Params | Field               | string     |
   Then the system returns a result with code "Created"
   And "my-user" is able to view rule type named "Integer Values Range" with following data:
      | Params        | Name                | Type       |
      | Type Params   | Minimum Value       | integer    |
      | Type Params   | Maximum Value       | integer    |
      | System Params | Table               | string     |
      | System Params | Field               | string     |