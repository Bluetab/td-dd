Feature: Quality Rules
  A Quality rule depends always on the existance of a quality control and will
  be related with a quality controll

  Scenario: Create a new Quality rule
    Given user "my-user" logged in the application
    And a existing Quality Control with following data:
      | Field               | Value                                                                                  |
      | Business Concept ID | MYID_333                                                                               |
      | Name                | Field's Quality Control                                                                |
      | Description         | In order to measure quality of this field we will check whether its values are correct |
      | Weight              | 50                                                                                     |
      | Priority            | Medium                                                                                 |
      | Population          | All clients who are older than 18                                                      |
      | Goal                | 98                                                                                     |
      | Minimum             | 80                                                                                     |
      | Type                | Integer Values Range                                                                   |
      | Type Params         | %-{ "Minimum Value": 18, "Maximum Value": 18 }                                         |
    And a existing Quality Rule Type with name "Integer Values Range" and the following parameters:
      | Params        | Name                | Type   |
      | Type Params   | Minimum Value       | int    |
      | Type Params   | Maximum Value       | int    |
      | System Params | Table               | string |
      | System Params | Field               | string |
    When "my-user" tries to create a Quality Rule associated to Quality Control "Field's Quality Control" and a Quality Rule "Integer Values Range" with following data:
      | Field               | Value                                                                                  |
      | Type                | Integer Values Range                                                                   |
      | System              | Oracle                                                                                 |
      | Name                | Age between 18 and 50                                                                  |
      | Description         | My Generic Quality Control Rule                                                        |
      | System Params       | %-{ "Table": "Clients", "Field": "Age" }                                               |
