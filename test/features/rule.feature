Feature: Rules
  A Rule depends always from a Business Concept, and will store some unique indetification
  for the Business Concept in order to have it linked. This Business Concept ID could be from true-dat
  Business Glossary service or a third-party Business Glossary
  A Rule has a workflow with following status depending on the executed action:
    | initial status   | action            | new status       |
    |                  | create            | defined          |
    | defined          | immplement        | implemented      |

  Scenario Outline: Create new Rule, validate types
    Given user "my-user" logged in the application
    When "my-user" tries to create a Rule of type <type> with following data and type_params <type_params>:
      | Field               | Value                                                                                  |
      | Business Concept ID | MYID_333                                                                               |
      | Name                | Field's Rule                                                                |
      | Description         | In order to measure quality of this field we will check whether its values are correct |
      | Weight              | 50                                                                                     |
      | Priority            | Medium                                                                                 |
      | Population          | All clients who are older than 18                                                      |
      | Goal                | 98                                                                                     |
      | Minimum             | 80                                                                                     |
    Then the system returns a result with code "Created"
    And "my-user" is able to view rule named "Field's Rule" with with following data:
      | Field               | Value                                                                                     |
      | Business Concept ID | MYID_333                                                                                  |
      | Name                | Field's Rule                                                                   |
      | Description         | In order to measure quality of this field we will check whether its values are correct    |
      | Status              | defined                                                                                   |
      | Weight              | 50                                                                                        |
      | Priority            | Medium                                                                                    |
      | Population          | All clients who are older than 18                                                         |
      | Goal                | 98                                                                                        |
      | Minimum             | 80                                                                                        |
      | Version             | 1                                                                                         |
    Examples:
      | type                 | type_params                           |
      | mandatory_field | %-{ } |
      # | min_text | %-{ "num_characters": 2 } |
      # | max_text | %-{ "num_characters": 21 } |
      # | date_format | %-{ } |
      # | numeric_format | %-{ } |
      # | decimal_format | %-{ "num_decimals": 4 } |
      # | in_list | %-{ "values_list": [1, 3, 5] } |
      # | unique_values | %-{ } |
      # | min_value | %-{ "min_value": 1 } |
      # | max_value | %-{ "max_value": 99 } |
      # | integer_values_range | %-{ "min_value": 1, "max_value": 99 } |
      # | integrity | %-{ } |
      # | max_date | %-{ "max_date": "2100-01-24" } |
      # | min_date | %-{ "min_date": "1970-01-01" } |
      # | dates_range | %-{ "min_date": "1970-01-01", "max_date": "2100-01-24" } |
