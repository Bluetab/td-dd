Feature: Data Dictionary Administration
  Creation of Data Sets (Files, Tables, Reports, ...) and Fields (field, column, ...)

  Scenario: Create a new Data Structure
    When "app-admin" tries to create a Data Structure with following data:
      | Field               | Value                                                                |
      | System              | SAS                                                                  |
      | Group               | Risks                                                                |
      | Name                | TKIDS0001                                                            |
      | Description         | We are describing this table as a table in Risks group in SAS System |
    Then the system returns a result with code "Created"
    And "app-admin" is able to view data structure with following data:
      | Field               | Value                                                                |
      | System              | SAS                                                                  |
      | Group               | Risks                                                                |
      | Name                | TKIDS0001                                                            |
      | Description         | We are describing this table as a table in Risks group in SAS System |
      | Last Modification   | Some timestamp                                                       |
      | Last User           | app-admin                                                            |
