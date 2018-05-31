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
      | Type Params         | %-Min Value: 0, Max Value: 120                                                         |
    And a existing Quality Rule Type with name "Integer Values Range" and the following parameters:
      | Params        | Name                | Type   |
      | Type Params   | Minimum Value       | int    |
      | Type Params   | Maximum Value       | int    |
      | System Params | Table               | string |
      | System Params | Field               | string |
