Feature: Quality Rules
  Add desscription

  Scenario: Create a new Quality Rule with only generic fields
    Given user "app-admin" is logged in the application
    And an existing Quality Control Type called "Quality Control Type" without any parameters
    And a Quality Control of type "Quality Control Type" with following data:
      | Field               | Value                                                                                  |
      | Type                | Quality Control Type                                                                   |
      | Business Concept ID | MYID_333                                                                               |
      | Name                | Quality Control Name                                                                   |
      | Description         | In order to measure quality of this field we will check whether its values are correct |
      | Weight              | 50                                                                                     |
      | Priority            | Medium                                                                                 |
      | Population          | All clients who are older than 18                                                      |
      | Goal                | 98                                                                                     |
      | Minimum             | 80                                                                                     |
    And an existing Quality Rule Type called "Quality Rule Type" without any parameters
    When "app-admin" tries to create a Quality Rule of type "Quality Rule Type" associated to Quality Control with Business Concept ID "MYID_333" and name "Quality Control Name" with following data:
      | Field               | Value                                                                                  |
      | Type                | Quality Rule Type                                                                      |
      | System              | Oracle                                                                                 |
      | Name                | Quality Rule Name                                                                      |
      | Descrition          | My Generic Quality Control Rule                                                        |
    Then the system returns a result with code "Created"
    And "app-admin" is able to view Quality Rule of type "Quality Rule Type" and name "Quality Rule Name" associated to Quality Control with Business Concept ID "MYID_333" and name "Quality Control Name" with following data:
      | Field               | Value                                                                                  |
      | Type                | Quality Rule Type                                                                      |
      | System              | Oracle                                                                                 |
      | Name                | Quality Rule Name                                                                      |
      | Descrition          | My Generic Quality Control Rule                                                        |
