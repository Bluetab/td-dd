# Changelog

## [3.7.0] 2019-09-30

### Added

- [TD-2010] As a Connector I want to delete all structures of a group
- [TD-2077] Support synchronous metadata upload for a specific data structure
- [TD-2089] Profiling support for structures
- [TD-2118] Metadata as mapping in data structures search
- [TD-2068] Use sortable normalizer for some fields in ES mappings
- [TD-1871] Structures CSV download

## [3.6.0] 2019-09-16

### Added

- [TD-1650] Automatic versioning of changed data structures
- [TD-2046] Bulk update endpoint for Data Catalog extra info
- [TD-2090] Search results and filters now use `:link_data_structure` permission instead of `:view_data_structure` depending on `referer` header

### Changed

- Metadata upload format (see config/metadata.exs for detail):
  - Structures CSV required fields:
    - `external_id` (globally unique)
    - `name`
    - `system` (or `POST` to `/systems/:system_external_id/metadata`)
    - `group`
    - `type`
  - Fields CSV required fields:
    - `external_id` (of structure)
    - `field_name`
    - `type`
  - Relations CSV required fields:
    - `parent_external_id`
    - `child_external_id`

## [3.5.5] 2019-09-09

### Changed

- Startup task to rename external_id of SQL server structures

## [3.5.2] 2019-09-04

### Fixed

- [TD-2087] DataStructure response excluded immediate parent from ancestry

## [3.5.1] 2019-09-03

### Fixed

- [TD-2080] DataStructureLoader was failing due to changes in [TD-2072]
- [TD-2081] Event stream consumer did not respect redis_host and port config options

## [3.5.0] 2019-09-02

### Changed

- [TD-2061] Data structure external id is now required and unique
- [TD-2072] Refactor model to move mutable/versionable fields from DataStructure to DataStructureVersion

### Fixed

- [TD-2047] Check status filter when retrieving search filters

## [3.3.0] 2019-08-05

### Added

- [TD-1560] Enriched description field in template content

### Changed

- [TD-2027] Improve indexing performance
- [TD-1985] Type of template field user with an aggregation size of 50
- [TD-2009] Get external id by data structure system and external id, fixed ancestry in structure view

### Fixed

- [TD-1991] Performance issues due to blocking Redis connections
- [TD-2028] Eliminate duplicated data structure versions
- [TD-2003] Avoid loading a structure with a relation with itself in bulk load

### Removed

- [TD-1534] Remove data fields from model

## [3.2.0] 2019-07-24

### Fixed

- [TD-1996] Change external_id to text in data_structures
- [TD-1854] Data field metadata is not updated during metadata upload

### Added

- [TD-1845] Soft deletion of data structures no longer present in CSV input for system/group
- [TD-1970] New endpoint for "api/systems/{system_external_id}/structures/{structure_external_id}"

### Changed

- [TD-1532] Improve support for linking with business concepts (fields are no longer used)
- [TD-2002] Update td-cache and delete permissions list from config
- [TD-1927] Allow structure "class" property to be specified in metadata CSV

## [3.1.0] 2019-07-08

### Changed

- [TD-1618] Cache improvements. Use td-cache instead of td-perms.
- [TD-1866] Exclude logic deleted data_structures in catalog navigation, catalog table and filters

## [3.0.1] 2019-07-05

### Fixed

- [TD-1967] Task to remove duplicate data structure versions, filter duplicates in CSV input

## [3.0.0] 2019-06-25

### Fixed

- [TD-1860] Fields were not associated to corresponding version when loading new version of existing structure
- [TD-1864] Indexes structures with 'field' class
- [TD-1851] Verify permissions while getting the root structures of a System

### Changed

- [TD-1793] Checks if field structure has df_content and enriches data_structure :show
- [TD-1891] Bulk load types translation from data fields to data structures
- [TD-1533] Ignores search term when it is no on Aggregation

## [2.21.0] 2019-06-10

### Fixed

- [TD-1825] Structures of fields with metadata type are not setting its type correctly - metadata type key is not correct

### Added

- [TD-1824] Bump td-perms version to fix relations key
- [TD-1702] Support new permission view_data_structures_profile

### Changed

- [TD-1847] Filter class field on system_datastructure to improve performance

### Removed

- [TD-1832] Removed business_concept_id from dataFields

## [2.20.1] 2019-05-28

### Added

- [TD-1819] Include external_id and class in data structure and data structure version show responses

## [2.20.0] 2019-05-27

### Added

- [TD-1703] Include system and ancestry in data structure and data structure version show responses

### Fixed

- [TD-1747] Structures upload is not creating relation between structures and fields when including version number
- [TD-1758] Structures with 'field' class are no indexed on create/upload
- [TD-1797] Structures of Fields of type Metric and Attribute must have that type instead of Field

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
