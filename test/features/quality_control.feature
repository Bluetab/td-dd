Feature: Quality Controls
  A Quality control depends always from a Business Concept, and will store some unique indetification
  for the Business Concept in order to have it linked. This Business Concept ID could be from true-dat
  Business Glossary service or a third-party Business Glossary
  A Quality Control has a workflow with following status depending on the executed action:
     | initial status   | action            | new status       |
     |                  | create            | defined          |
     | defined          | delete            | deleted          |
     | defined          | process result    | built            |

  Scenario: Create a new Quality Control with only generic fields
    Given user "app-admin" is logged in the application
    And an existing Quality Control type called "Generic" without any parameters
    When "app-admin" tries to create a Quality Control of type "Generic" with following data:
      | Field               | Value                                                                                  |
      | Type                | Generic                                                                                |
      | Business Concept ID | MYID_333                                                                               |
      | Name                | Field's Quality Control                                                                |
      | Description         | In order to measure quality of this field we will check whether its values are correct |
      | Weight              | 50                                                                                     |
      | Priority            | Medium                                                                                 |
      | Population          | All clients who are older than 18                                                      |
      | Goal                | 98                                                                                     |
      | Minimum             | 80                                                                                     |
      #| DQ Goal             | 98                                                                                     |
      #| DQ Minimum          | 80                                                                                     |
    Then the system returns a result with code "Created"
    And "app-admin" is able to view quality control with Business Concept ID "MYID_333" and name "Field's Quality Control" with following data:
      | Field               | Value                                                                                  |
      | Type                | Generic                                                                                |
      | Business Concept ID | MYID_333                                                                               |
      | Name                | Field's Quality Control                                                                |
      | Description         | In order to measure quality of this field we will check whether its values are correct |
      | Status              | defined                                                                                |
      | Weight              | 50                                                                                     |
      | Priority            | Medium                                                                                 |
      | Population          | All clients who are older than 18                                                      |
      # | DQ Goal             | 98                                                                                     |
      # | DQ Minimum          | 80                                                                                     |
      | Goal                | 98                                                                                     |
      | Minimum             | 80                                                                                     |
      | Last Modification   | Some timestamp                                                                         |
      | Last User           | app-admin                                                                              |
      | Version             | 1                                                                                      |

  Scenario: Create a new Quality Control with a type that has parameters
    Given user "app-admin" is logged in the application
    And an existing Quality Control type called "Integer Values Range" with description "Check Range of values in integer format" and following parameters:
      | Parameter           | Type         |
      | Min Value           | integer      |
      | Max Value           | integer      |
     When "app-admin" tries to create a Quality Control of type "Integer Values Range" with following data:
      | Field               | Value                                                                                    |
      | Type                | Integer Values Range                                                                                  |
      | Business Concept ID | MYID_001                                                                                 |
      | Name                | Data for BC MYID_001 must be a value between 0 and 100                                   |
      | Description         | In order to measure quality of this field we will check whether its is between 0 and 100 |
      | Weight              | 30                                                                                       |
      | Priority            | Medium                                                                                   |
      | Population          | All clients who are older than 18                                                        |
      | Goal                | 95                                                                                       |
      | Minimum             | 70                                                                                       |
      | Min Value           | 0                                                                                        |
      | Max Value           | 100                                                                                      |
     Then the system returns a result with code "Created"
     And "app-admin" is able to view quality control with Business Concept ID "MYID_001" and name "Data for BC MYID_001 must be a value between 0 and 100" with following data:
       | Field               | Value                                                                                     |
       | Type                | Integer Values Range                                                                      |
       | Business Concept ID | MYID_001                                                                                  |
       | Name                | Data for BC MYID_001 must be a value between 0 and 100                                    |
       | Description         |  In order to measure quality of this field we will check whether its is between 0 and 100 |
       | Status              | defined                                                                                   |
       | Weight              | 30                                                                                        |
       | Priority            | Medium                                                                                    |
       | Population          | All clients who are older than 18                                                         |
       | Goal                | 95                                                                                        |
       | Minimum             | 70                                                                                        |
       | Min Value           | 0                                                                                         |
       | Max Value           | 100                                                                                       |
       | Last Modification   | Some timestamp                                                                            |
       | Last User           | app-admin                                                                                 |
       | Version             | 1                                                                                         |

  Scenario: List quality control types
   Given user "app-admin" is logged in the application
   And an existing quality control type:
     | Name                 | Description                             | Parameter           | Type         |
     | Integer Values Range | Check Range of values in integer format | Min Value           | integer      |
     |                      |                                         | Max Value           | integer      |
     | Integer Min Value    | Check Min Value in integer              | Min Value           | integer      |
     | Integer Max Value    | Check Max Value in integer              | Max Value           | integer      |
   When "app-admin" tries to list quality control types
   Then the system returns a result with code "Ok"
   And "app-admin" is able to view quality control types:
    | Name                 |
    | Integer Values Range |
    | Integer Min Value    |
    | Integer Max Value    |

  Scenario: List quality control type parameters
    Given user "app-admin" is logged in the application
    And an existing quality control type:
      | Name                 | Description                             | Parameter           | Type         |
      | Integer Values Range | Check Range of values in integer format | Min Value           | integer      |
      |                      |                                         | Max Value           | integer      |
    When "app-admin" tries to list parameters of quality control type "Integer Values Range"
    Then the system returns a result with code "Ok"
    And "app-admin" is able to view quality control type parameters:
      | name         | type    |
      | Min Value    | integer |
      | Max Value    | integer |

  Scenario: Receive and store results data for existing Quality Controls in bulk mode
    Given some quality controls exist in the system with following data:
      | type    | business_concept_id | name                    | description   | weight | priority | population  | goal  | minimum |
      | Generic | MYID_333            | Field's Quality Control | Description 1 | 50     | Medium   | All clients | 98    | 80      |
      | Generic | MYID_333            | Field Not nulls         | Description 2 | 50     | High     | All clients | 100   | 90      |
      | Generic | MYID_334            | Range of values         | Description 3 | 50     | Low      | All clients | 98    | 60      |
      | Generic | MYID_335            | Format validation       | Description 4 | 50     | Medium   | All clients | 95    | 80      |
      | Generic | MYID_336            | Format validation       | Description 5 | 50     | Medium   | All clients | 95    | 80      |
    When "app-admin" tries to load quality controls results with following information:
      | system  | group        | structure_name | field_name          | business_concept_id    | quality_control_name     | date       | result |
      | SAS     | Risks        | TKIDS0001      | My_Personal01_Field | MYID_333               | Field's Quality Control  | 2018-03-08 | 40     |
      | SAS     | Risks        | TKIDS0001      | My_Personal02_Field | MYID_333               | Field Not nulls          | 2018-03-08 | 90     |
      | SAS     | Risks        | TKIDS0001      | My_Personal03_Field | MYID_334               | Range of values          | 2018-03-08 | 90     |
      | SAS     | Risks        | TKIDS0001      | My_Personal04_Field | MYID_335               | Format validation        | 2018-03-08 | 90     |
    Then "app-admin" is able to view quality control results for Business Concept ID "MYID_333" with following data:
      | system  | group        | structure_name | field_name          | business_concept_id    | quality_control_name     | date       | result |
      | SAS     | Risks        | TKIDS0001      | My_Personal01_Field | MYID_333               | Field's Quality Control  | 2018-03-08 | 40     |
      | SAS     | Risks        | TKIDS0001      | My_Personal02_Field | MYID_333               | Field Not nulls          | 2018-03-08 | 90     |
