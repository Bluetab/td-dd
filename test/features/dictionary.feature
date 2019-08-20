Feature: Data Dictionary Administration
  Creation of Data Sets (Files, Tables, Reports, ...) and Fields (field, column, ...)

  Scenario: Create a new Data Structure
    Given an existing system with external reference "S001" and name "SAS"
    When "app-admin" tries to create a Data Structure in the System "S001" with following data:
      | Field               | Value                                                                |
      | Group               | Risks                                                                |
      | Name                | TKIDS0001                                                            |
      | External ID         | Risks/TKIDS001                                                       |
      | Description         | We are describing this table as a table in Risks group in SAS System |
      | Type                | Table                                                                |
      | Organizational Unit | General Management                                                   |
    Then the system returns a result with code "Created"
    And "app-admin" is able to view data structure in system "S001" group "Risks" and structure "TKIDS0001"  with following data:
      | Field               | Value                                                                |
      | Group               | Risks                                                                |
      | Name                | TKIDS0001                                                            |
      | External ID         | Risks/TKIDS001                                                       |
      | Description         | We are describing this table as a table in Risks group in SAS System |
      | Type                | Table                                                                |
      | Organizational Unit | General Management                                                   |
      | Last Modification   | Some timestamp                                                       |

  Scenario: Load metadata (structures and fields) into the system in bulk mode
    Given the existing systems:
      | Reference | Name |
      | S001      | SAS  |
      | S002      | PI   |

    When "app-admin" tries to load dictionary data with following information:
      | File           | System | Group    | Structure_Name | External_ID | Field_Name          | Description                        | Type      | Precision | Nullable | Business_Concept_ID | Domain_Name |
      | Data Structure | SAS    | Risks    | TKIDS0001      | TKIDS0001   |                     | TKIDS0001 Description              | TABLE     |           |          |                     | Domain_1    |
      | Data Structure | SAS    | Risks    | TKIDS0002      | TKIDS0002   |                     | TKIDS0002 Description              | TABLE     |           |          |                     | Domain_1    |
      | Data Structure | PI     | Teradata | TKIDS0003      | TKIDS0003   |                     | TKIDS0003 Description              | TABLE     |           |          |                     |             |
      | Field          | SAS    | Risks    | TKIDS0001      | TKIDS0001   | My_Personal01_Field | My_Personal01_Field Description    | CHAR      | 20        | Yes      | BCID001             |             |
      | Field          | SAS    | Risks    | TKIDS0001      | TKIDS0001   | My_Personal02_Field | My_Personal02_Field Description    | VARCHAR   | 80        | No       | BCID002             |             |
      | Field          | SAS    | Risks    | TKIDS0001      | TKIDS0001   | My_Personal03_Field | My_Personal03_Field Description    | DATE      |           | No       | BCID003             |             |
      | Field          | SAS    | Risks    | TKIDS0002      | TKIDS0002   | My_Personal01_Field | My_Personal01bis_Field Description | TIMESTAMP |           | No       | BCID001             |             |
      | Field          | SAS    | Risks    | TKIDS0002      | TKIDS0002   | My_Personal04_Field | My_Personal04_Field Description    | SMALLINT  |           | Yes      |                     |             |
    Then the system returns a result with code "Accepted"
    And when the system has finished loading the metadata
    And "app-admin" is able to view data field "My_Personal01_Field" from system "S001" group "Risks" and structure "TKIDS0002" with following data:
      | Field             | Value                              |
      | Field Name        | My_Personal01_Field                |
      | Type              | TIMESTAMP                          |
      | Precision         |                                    |
      | Nullable          | Yes                                |
      | Description       | My_Personal01bis_Field Description |
      | Last Modification | Some timestamp                     |