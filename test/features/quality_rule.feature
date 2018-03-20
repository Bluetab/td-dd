Feature: Quality Rules
  Add desscription

  Scenario: Create a new Quality Rule with only generic fields
    Given user "app-admin" is logged in the application
    And an existing Quality Control type called "Quatity Control Type" without any parameters
    And a Quality Control of type "Generic" with following data:
      | Field               | Value                                                                                  |
      | Type                | Quatity Control Type                                                                                |
      | Business Concept ID | MYID_333                                                                               |
      | Name                | Quality Control Name                                                                |
      | Description         | In order to measure quality of this field we will check whether its values are correct |
      | Weight              | 50                                                                                     |
      | Priority            | Medium                                                                                 |
      | Population          | All clients who are older than 18                                                      |
      | Goal                | 98                                                                                     |
      | Minimum             | 80                                                                                     |
    And an existing Quality Rule type called "Generic" without any parameters
    When "app-admin" tries to create a Quality Control Rule of type "Generic" child of Quality Control of type "Quatity Control Type" and name "Quality Control Name" with following data:
      | Field               | Value                                                                                  |
      | Type                | Generic                                                                                |
      | System              | Oracle                                                                                 |
      | Name                | Generic Quality Control Rule                                                           |
      | Descrition          | My Generic Quality Control Rule                                                        |
    Then the system returns a result with code "Created"
    And "app-admin" is able to view quality control rule of type "Generic" name "Generic Quality Control Rule" child of Quality Control of type "Quality Control Type" and name "Quality Control Name" with following data:
      | Field               | Value                                                                                  |
      | Type                | Generic                                                                                |
      | System              | Oracle                                                                                 |
      | Name                | Generic Quality Control Rule                                                           |
      | Descrition          | My Generic Quality Control Rule                                                        |
