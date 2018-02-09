Feature: Data Dictionary Administration
  Creation of Data Sets (Files, Tables, Reports, ...) and Fields (field, column, ...)

  Scenario: Create a new Data Structure
    Given user "app-admin" is logged in the application
    When "app-admin" tries to create a Data Structure with following data:
      | Field               | Value                                                                                  |
      | System              | SAS                                                                                    |
      | Group               | Risks                                                                                  |
      | Name                | TKIDS0001                                                                              |
      | Description         | In order to measure quality of this field we will check whether its values are correct |
    Then the system returns a result with code "Created"
    And "app-admin" is able to view data structure with following data:
      | Field               | Value                                                                                  |
      | System              | SAS                                                                                    |
      | Group               | Risks                                                                                  |
      | Name                | TKIDS0001                                                                              |
      | Description         | In order to measure quality of this field we will check whether its values are correct |
      | Last Modification   | Some timestamp                                                                         |
      | Last User           | app-admin                                                                              |
