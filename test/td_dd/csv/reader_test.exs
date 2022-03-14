defmodule TdDd.CSV.ReaderTest do
  use TdDd.DataCase
  alias TdDd.CSV.Reader

  @structure_import_schema Application.compile_env(:td_dd, :metadata)[:structure_import_schema]
  @field_import_schema Application.compile_env(:td_dd, :metadata)[:field_import_schema]
  @field_import_required Application.compile_env(:td_dd, :metadata)[:field_import_required]

  setup context do
    if path = context[:fixture] do
      stream = File.stream!("test/fixtures/" <> path)
      [stream: stream]
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
      defaults = %{version: 0, domain_ids: [42]}
      required = [:name]

      {:ok, [r2, r3, r4, r5]} =
        stream
        |> Reader.read_csv(
          defaults: defaults,
          schema: @structure_import_schema,
          required: required,
          booleans: ["m:bool"]
        )

      assert r2 == %{
               domain_ids: [42],
               description: "description",
               metadata: %{"foo" => "foo1", "bool" => true},
               mutable_metadata: %{"foo" => %{"bar" => "muta_foo"}},
               name: "name",
               version: 0
             }

      assert r3 == %{
               domain_ids: [42],
               class: "class1",
               metadata: %{
                 "bar" => %{"baz" => %{"spqr" => "spqr", "xyzzy" => "xyzzy"}},
                 "bool" => false
               },
               mutable_metadata: %{},
               name: "name",
               version: 0
             }

      assert r4 == %{
               domain_ids: [42],
               description: "description",
               metadata: %{},
               mutable_metadata: %{"foo" => %{"bar" => "baz"}},
               name: "name",
               version: 0
             }

      assert r5 == %{
               domain_ids: [42],
               description: "description",
               metadata: %{},
               mutable_metadata: %{},
               name: "name",
               version: 0
             }
    end

    @tag fixture: "structures.csv"
    test "read_csv/2 returns ok with records and default domain_ids", %{stream: stream} do
      defaults = %{version: 0, domain_ids: [43]}
      required = [:name]

      {:ok, results} =
        stream
        |> Reader.read_csv(
          defaults: defaults,
          schema: @structure_import_schema,
          required: required,
          booleans: ["m:bool"]
        )

      for result <- results do
        assert %{domain_ids: [43]} = result
      end
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
               external_id: "1",
               field_external_id: "987",
               field_name: "Field1",
               metadata: %{},
               mutable_metadata: %{},
               nullable: true,
               type: "Column"
             }

      assert r2 == %{
               external_id: "2",
               field_name: "Field2",
               metadata: %{},
               mutable_metadata: %{},
               nullable: false,
               type: "Column"
             }
    end
  end
end
