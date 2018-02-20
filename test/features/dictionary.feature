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

  Scenario: Create a new field related to an existing Data Structure inside Data Dictionary
    Given and existing data structure with following data:
      | Field               | Value                                                                |
      | System              | SAS                                                                  |
      | Group               | Risks                                                                |
      | Name                | TKIDS0001                                                            |
      | Description         | We are describing this table as a table in Risks group in SAS System |
    When "app-admin" tries to create a Data Field from system "SAS" group "Risks" and structure "TKIDS0001" with following data:
      | Field               | Value                                                |
      | Field Name          | My_Personal_Field                                    |
      | Type                | CHAR                                                 |
      | Precision           | 20                                                   |
      | Nullable            | Yes                                                  |
      | Description         | My personal fields can be only used by me and myself |
    Then the system returns a result with code "Created"
    And "app-admin" is able to view data field "My_Personal_Field" from system "SAS" group "Risks" and structure "TKIDS0001" with following data:
      | Field               | Value                                                |
      | Field Name          | My_Personal_Field                                    |
      | Type                | CHAR                                                 |
      | Precision           | 20                                                   |
      | Nullable            | Yes                                                  |
      | Description         | My personal fields can be only used by me and myself |
#      | Business Concept ID |                                                      |
      | Last Modification   | Some timestamp                                       |
      | Last User           | app-admin                                            |
