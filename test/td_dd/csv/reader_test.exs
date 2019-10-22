defmodule TdDd.CSV.ReaderTest do
  use TdDd.DataCase
  alias TdDd.CSV.Reader

  @structure_import_schema Application.get_env(:td_dd, :metadata)[:structure_import_schema]
  @field_import_schema Application.get_env(:td_dd, :metadata)[:field_import_schema]
  @field_import_required Application.get_env(:td_dd, :metadata)[:field_import_required]

  setup context do
    if path = context[:fixture] do
      stream = File.stream!("test/fixtures/" <> path)
      {:ok, stream: stream}
    else
      :ok
    end
  end

  describe "CSV.Reader" do
    @tag fixture: "structures_errors.csv"
    test "read_csv/2 returns errors with index", %{stream: stream} do
      defaults = %{version: 0}
      required = [:name]

      {:error, [{r1, l}]} =
        stream
        |> Reader.read_csv(
          domain_map: %{"domain1" => 42},
          defaults: defaults,
          schema: @structure_import_schema,
          required: required,
          booleans: ["m:bool"]
        )

      assert Keyword.get(r1.errors, :name) != nil
      assert l == 4
    end

    @tag fixture: "structures.csv"
    test "read_csv/2 returns ok with records", %{stream: stream} do
      defaults = %{version: 0}
      required = [:name]

      {:ok, [r2, r3, r4]} =
        stream
        |> Reader.read_csv(
          domain_map: %{"domain1" => 42},
          defaults: defaults,
          schema: @structure_import_schema,
          required: required,
          booleans: ["m:bool"]
        )

      assert r2 == %{
               description: "description",
               metadata: %{"foo" => "foo1", "bool" => true},
               name: "name",
               version: 0
             }

      assert r3 == %{
               class: "class1",
               metadata: %{
                 "bar" => %{"baz" => %{"spqr" => "spqr", "xyzzy" => "xyzzy"}},
                 "bool" => false
               },
               name: "name",
               version: 0
             }

      assert r4 == %{
               description: "description",
               domain_id: 42,
               metadata: %{},
               name: "name",
               ou: "domain1",
               version: 0
             }
    end

    @tag fixture: "structures.csv"
    test "read_csv/2 returns ok with records and ou as specified domain", %{stream: stream} do
      defaults = %{version: 0}
      required = [:name]

      {:ok, results} =
        stream
        |> Reader.read_csv(
          domain_map: %{"domain1" => 42, "domain2" => 43},
          defaults: defaults,
          schema: @structure_import_schema,
          required: required,
          domain: "domain2",
          booleans: ["m:bool"]
        )

      assert Enum.all?(results, fn %{ou: ou, domain_id: domain_id} ->
               domain_id == 43 && ou == "domain2"
             end)
    end

    @tag fixture: "fields.csv"
    test "read_csv/2 transforms nullable values to boolean", %{stream: stream} do
      system_map = %{"System" => 42}

      {:ok, [r1, r2]} =
        stream
        |> Reader.read_csv(
          schema: @field_import_schema,
          system_map: system_map,
          required: @field_import_required,
          booleans: ["nullable"]
        )

      assert r1 == %{
               metadata: %{},
               external_id: "1",
               field_name: "Field1",
               nullable: true,
               type: "Column"
             }

      assert r2 == %{
               metadata: %{},
               external_id: "2",
               field_name: "Field2",
               nullable: false,
               type: "Column"
             }
    end
  end
end
