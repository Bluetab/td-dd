# Truedat Data Dictionary

`td-dd` is a back-end service developed as part of Truedat project that provides
API's for the following functionality:

- Data Catalog
- Data Lineage
- Connector Management
- Data Quality

## Getting Started

These instructions will get you a copy of the project up and running on your
local machine for development and testing purposes. See deployment for notes on
how to deploy the project on a live system.

### Prerequisites

Install dependencies with `mix deps.get`

To start your Phoenix server:

### Installing

- Create and migrate your database with `mix ecto.create && mix ecto.migrate`
- Start Phoenix endpoint with `mix phx.server`
- The `td-dd` API is published on [`localhost:4005`](http://localhost:4005)
- The `td-cx` API is published on [`localhost:4008`](http://localhost:4008)

## Running the tests

Run all aplication tests with `mix test`

## Environment variables

### SSL conection

- DB_SSL: boolean value, to enable TSL config, by default is false.
- DB_SSL_CACERTFILE: path of the certification authority cert file "/path/to/ca.crt", required when DB_SSL is true.
- DB_SSL_VERSION: available versions are tlsv1.2, tlsv1.3 by default is tlsv1.2.

### Lineaje nodes domains id refresh

- LINEAGE_NODES_DOMAINS_IDS_REFRESHER: default hourly, refresh the lineaje nodes domains ids column to show graph

### Elastic bulk page size configuration

- BULK_PAGE_SIZE_GRANTS: default 500
- BULK_PAGE_SIZE_IMPLEMENTATIONS: default 100
- BULK_PAGE_SIZE_JOBS: default 100
- BULK_PAGE_SIZE_RULES: default 100
- BULK_PAGE_SIZE_STRUCTURES: default 1000
- BULK_PAGE_SIZE_GRANT_REQUESTS: default 500

### Store chunk size

- GRANT_STORE_CHUNK_SIZE: default 1000
- GRANT_REQUEST_STORE_CHUNK_SIZE: default 1000
- STRUCTURE_STORE_CHUNK_SIZE: default 1000
- DSV_STORE_CHUNK_SIZE: default 1000

# If the variable is set to false, it will not be deleted in the case that there is no index in the hot swap process.

- DELETE_EXISTING_INDEX: detault true

### Elastic Configuracion

# The bulk_wait_interval variable defines the time interval between batches of bulk operations in Elasticsearch.

BULK_WAIT_INTERVAL_GRANTS: default 0

### Elastic aggregations

- The aggregation variables are defined as follows: AGG\_<AGGREGATION_NAME>\_SIZE

### ElasticSearch authentication

#### (Optional) Basic HTTP authentication

These environment variables will add the Authentication header on each request
with value `Basic <ES_USERNAME>:<ES_PASSWORD>`

- ES_USERNAME: Username
- ES_PASSWORD: Password

####  Disable the language-specific stemming functionality

In the long term, we should aim to filter only by keyword fields in our connectors. However, setting the variable
`APPLY_LANG_SETTINGS_STRUCTURES` to false will disable the language-specific stemming functionality provided by Elasticsearch,
which may impact search accuracy

- APPLY_LANG_SETTINGS_STRUCTURES: default true

#### (Optional) ApiKey authentication

This environment variables will add the Authentication header on each request
with value `ApiKey <ES_API_KEY>`

- ES_API_KEY: ApiKey

#### (Optional) HTTP SSL Configuration (Normally required for ApiKey authentication)

These environment variables will configure CA Certificates for HTTPS requests

- ES_SSL: [true | false] required to activate following options
- ES_SSL_CACERTFILE: (Optional) Indicate the cacert file path. If not set, a certfile will be automatically generated by `:certifi.cacertfile()`
- ES_SSL_VERIFY: (Optional) [verify_peer | verify_none] defaults to `verify_none`

## Deployment

Ready to run in production? Please [check our deployment
guides](http://www.phoenixframework.org/docs/deployment).

## Built With

- [phoenix](https://hex.pm/packages/phoenix) - A productive web framework
- [ecto](https://hex.pm/packages/ecto) - Elixir toolkit for database integration
- [postgrex](https://hex.pm/packages/postgrex) - Elixir PostgreSQL driver
- [cowboy](https://hex.pm/packages/cowboy) - An HTTP server for Erlang/OTP
- [httpoison](https://hex.pm/packages/httpoison) - An HTTP client
- [credo](https://hex.pm/packages/credo) - Static code analysis
- [guardian](https://hex.pm/packages/guardian) - Authentication library
- [bodyguard](https://hex.pm/packages/bodyguard) - Authorization library
- [ex_machina](https://hex.pm/packages/ex_machina) - A factory library for test
  data
- [cors_plug](https://hex.pm/packages/cors_plug) - Plug for CORS support
- [elasticsearch](https://hex.pm/packages/elasticsearch) - Client for
  Elasticsearch
- [vaultex](https://hex.pm/packages/vaultex) - Client for HashiCorp Vault

## Authors

- **Bluetab Solutions Group, SL** - _Initial work_ -
  [Bluetab](http://www.bluetab.net)

See also the list of [contributors](https://github.com/bluetab/td-dd) who
participated in this project.

## License

This program is free software: you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation, either version 3 of the License, or (at your option) any later
version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with
this program. If not, see https://www.gnu.org/licenses/.

In order to use this software, it is necessary that, depending on the type of
functionality that you want to obtain, it is assembled with other software whose
license may be governed by other terms different than the GNU General Public
License version 3 or later. In that case, it will be absolutely necessary that,
in order to make a correct use of the software to be assembled, you give
compliance with the rules of the concrete license (of Free Software or Open
Source Software) of use in each case, as well as, where appropriate, obtaining
of the permits that are necessary for these appropriate purposes.
