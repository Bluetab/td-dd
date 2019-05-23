# Changelog

## [Unreleased]

### Added

- [TD-1703] Include system and ancestry in data structure and data structure version show responses

### Fixed

- [TD-1747] Structures upload is not creating relation between structures and fields when including version number
- [TD-1758] Structures with 'field' class are no indexed on create/upload

## [2.19.0] 2019-05-14

### Fixed

- [TD-1774] Newline is missing in logger format

### Added

- [TD-1704] Index path of data structures and return in search results
- Metadata upload success response is now 202 Accepted instead of 204 No Content

## [2.18.0] 2019-04-30

### Fixed

- [TD-1697] Dynamic content indexing and mapping

## [2.17.0] 2019-04-17

### Added

- [TD-1597] allow deletion of data structures with relations
- [TD-1593] System as an independent entity
- [TD-1626] Load data fields as structures
- [TD-1634] Include data structure metadata field to selectively disable indexing ("indexable" == "false")
- Improve elasticsearch index mappings
- [TD-1554] added endpoint for getting root structures of a system

### Changed

- [TD-1627] Removes df_name from the structure and uses the structure type as definition of template
- [TD-1636] Use alpine:3.9 as base image for docker runtime

## [2.16.0] 2019-04-01

### Added

- [TD-1571] Elixir's Logger config will check for EX_LOGGER_FORMAT variable to override format

### Changed

- [TD-1530] Changed csv upload to write extra fields on metadata

## [2.15.0] 2019-03-18

### Changed

- [TD-1543] Updated to Phoenix 1.4, Ecto 3.0, Cowboy 2.0
- [TD-1526] Include parents and siblings in show data_structure response

## [2.14.0] 2019-03-04

### Changed

- Increase metadata upload file limit from 20M to 100M

## [2.12.1] 2019-01-28

### Changed

- Update td-df-lib version

## [2.12.0] 2019-01-24

### Changed

- [TD-1320] Aggregations are returned on data structures search

## [2.11.1] 2019-01-17

### Changed

- New cache to access linked business concepts of a field (TdPerms.RelationCache)
- Bump versions of the libraries td-perms and td-df-lib

## [2.11.0] 2019-01-16

### Fixed

- Bulk index data structures in batches of 100 to avoid reaching HTTP request size limit

## [2.10.8] 2019-01-08

### Fixed

- Added type field to structure index that was wrongly removed

## [2.10.7] 2018-12-20

### Added

- [TD-1306] Add new field external_id to link data_structures with parents, children and fields.

## [2.10.6] 2018-12-20

### Changed

- Reindex data structures in background
- Reindex data structures after metadata is loaded

### Fixed

- Metadata loader structure diff was not calculating correctly the fields to be removed

## [2.10.2] 2018-12-19

### Changed

- Update td-perms to 2.10.0
- Update td-df-lib to 2.10.0
- Improvements on authentication for testing. Creating a user, creates a session in the Auth Mock
- Created TaxonomyMockCache for domain related testing
- [TD-1198] add functionality for confidential data structure
  - added field confidential to data_structure
  - check for manage_confidential_structures on listing and updating data_structures
  - added elastic_search filter regarding confidential permissions

## [2.10.1] 2018-12-17

### Changed

- Update HTTPoison to 1.5.0
- Increase elasticsearch client default `recv_timeout` to 20 seconds
- Increase filter aggregation size to 50
- Remove "name" filter

## [2.10.0] 2018-12-12

### Changed

- [TD-1313] Adds type to structure filters

## [2.9.4] 2018-12-06

### Changed

- [TD-1104] Improved support for data structure versions

## [2.9.3] 2018-12-04

### Added

- [TD-1104] API endpoint `/api/data_structures/{id}/versions/{version}` to read specific version of a data structure

## [2.9.2] 2018-12-04

### Changed

- [TD-1153] Data Structure :index now looks for sort query from client to pass to elasticsearch

## [2.9.1] 2018-12-04

### Added

- [TD-1104] Support explicit version in data_structures metadata upload

## [2.9.0] 2018-12-01

### Added

- [TD-1207] Parent/child relationships between data structure versions

## [2.8.6] 2018-11-22

### Added

- [TD-1186] Adds dynamic form fields to structure filters

## [2.8.5] 2018-11-22

### Changed

- Order search results by name.raw

## [2.8.4] 2018-11-22

### Changed

- Configure Ecto to use UTC datetime for timestamps

## [2.8.3] 2018-11-20

### Added

- New endpoint to upload metadata `POST /api/data_structures/metadata`

## [2.8.2] 2018-11-20

### Added

- Data structure view return domain_id

## [2.8.1] 2018-11-19

### Added

- [TD-1062] Support for Dynamic Forms in data structures

### Removed

- Remove LOPD field from data structures

## [2.8.0] 2018-11-15

### Added

- [TD-1104] Initial support for versioning of data structures

## [2.6.2] 2018-10-30

### Added

- Modify endpoint from /api/search/reindex_all to /api/data_structures/search/reindex_all
- Verify if the user is admin while calling reindex_all
