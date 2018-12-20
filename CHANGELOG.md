# Changelog

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
