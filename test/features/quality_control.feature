Feature: Quality Controls
  A Quality control depends always from a Business Concept, and will store some unique indetification
  for the Business Concept in order to have it linked. This Business Concept ID could be from true-dat
  Business Glossary service or a third-party Business Glossary
  A Quality Control has a workflow with following status depending on the executed action:
    | initial status   | action            | new status       |
    |                  | create            | defined          |
    | defined          | immplement        | implemented      |

  Scenario: Create a new Quality Control with only generic fields
    Given user "my-user" is logged in the application
    When "my-user" tries to create a Quality Control with following data:
      | Field               | Value                                                                                  |
      | Business Concept ID | MYID_333                                                                               |
      | Name                | Field's Quality Control                                                                |
      | Description         | In order to measure quality of this field we will check whether its values are correct |
      | Weight              | 50                                                                                     |
      | Priority            | Medium                                                                                 |
      | Population          | All clients who are older than 18                                                      |
      | Goal                | 98                                                                                     |
      | Minimum             | 80                                                                                     |
   Then the system returns a result with code "Created"
   And "my-user" is able to view quality control named "Field's Quality Control" with with following data:
     | Field               | Value                                                                                     |
     | Business Concept ID | MYID_333                                                                                  |
     | Name                | Field's Quality Control                                    |
     | Description         | In order to measure quality of this field we will check whether its values are correct    |
     | Status              | defined                                                                                   |
     | Weight              | 50                                                                                        |
     | Priority            | Medium                                                                                    |
     | Population          | All clients who are older than 18                                                         |
     | Goal                | 98                                                                                        |
     | Minimum             | 80                                                                                        |
     | Version             | 1                                                                                         |
