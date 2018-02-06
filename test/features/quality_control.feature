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
      | Goal                | 98                                                                                     |
      | Minimum             | 80                                                                                     |
      | Last Modification   | Some timestamp                                                                         |
      | Last User           | app-admin                                                                              |
      | Version             | 1                                                                                      |
