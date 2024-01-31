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

## Deployment

Ready to run in production? Please [check our deployment
guides](http://www.phoenixframework.org/docs/deployment).

## Built With

- [phoenix](https://hex.pm/packages/phoenix) - A productive web framework
- [ecto](https://hex.pm/packages/ecto) - Elixir toolkit for database integration
- [postgrex](https://hex.pm/packages/postgrex) - Elixir PostgreSQL driver
- [gettext](https://hex.pm/packages/gettext) - Internationalization and
  localization support
- [cowboy](https://hex.pm/packages/cowboy) - An HTTP server for Erlang/OTP
- [httpoison](https://hex.pm/packages/httpoison) - An HTTP client
- [credo](https://hex.pm/packages/credo) - Static code analysis
- [guardian](https://hex.pm/packages/guardian) - Authentication library
- [canada](https://hex.pm/packages/canada) - A declarative permissions library
- [ex_machina](https://hex.pm/packages/ex_machina) - A factory library for test
  data
- [cors_plug](https://hex.pm/packages/cors_plug) - Plug for CORS support
- [phoenix_swagger](https://hex.pm/packages/phoenix_swagger) - Swagger
  integration for Phoenix framework
- [ex_json_schema](https://hex.pm/packages/ex_json_schema) - JSON Schema
  validator
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

## Branch for nhs
nhs-main