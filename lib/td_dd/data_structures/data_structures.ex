defmodule TdDd.DataStructures do
  @moduledoc """
  The DataStructures context.
  """

  import Ecto.Query, warn: false

  alias TdDd.Repo

  alias TdDd.DataStructures.DataStructure
  alias TdDd.DataStructures.DataStructureVersion
  alias TdDd.Utils.CollectionUtils
  alias TdDfLib.Validation
  alias TdPerms.DataFieldCache
  alias TdPerms.RelationCache

  @df_cache Application.get_env(:td_dd, :df_cache)
  @search_service Application.get_env(:td_dd, :elasticsearch)[:search_service]

  @doc """
  Returns the list of data_structures.

  ## Examples

      iex> list_data_structures()
      [%DataStructure{}, ...]

  """
  def list_data_structures(params \\ %{}) do
    filter = build_filter(DataStructure, params)

    DataStructure
    |> where([ds], ^filter)
    |> Repo.all()
    |> Repo.preload(:system)
  end

  def list_data_structures_with_no_parents(params \\ %{}) do
    filter = build_filter(DataStructure, params)

    DataStructure
    |> where([ds], ^filter)
    |> Repo.all()
    |> Repo.preload([versions: :parents])
    |> Repo.preload(:system)
    |> Enum.filter(&structure_has_versions?/1)
    |> Enum.filter(&last_version_is_root?/1)
  end

  defp structure_has_versions?(%{versions: []}), do: false
  defp structure_has_versions?(_), do: true

  defp last_version_is_root?(%{versions: versions}) do
    versions
    |> Enum.sort_by(&(&1.version))
    |> Enum.reverse
    |> Enum.at(0)
    |> Map.get(:parents)
    |> Enum.empty?
  end

  def build_filter(schema, params) do
    params = CollectionUtils.atomize_keys(params)
    fields = schema.__schema__(:fields)
    dynamic = true

    Enum.reduce(Map.keys(params), dynamic, fn key, acc ->
      case Enum.member?(fields, key) do
        true -> add_filter(key, params[key], acc)
        false -> acc
      end
    end)
  end

  defp add_filter(key, value, acc) do
    cond do
      is_list(value) and value == [] ->
        acc

      is_list(value) ->
        dynamic([ds], field(ds, ^key) in ^value and ^acc)

      is_nil(value) ->
        dynamic([ds], is_nil(field(ds, ^key)) and ^acc)

      value ->
        dynamic([ds], field(ds, ^key) == ^value and ^acc)
    end
  end

  @doc """
  Gets a single data_structure.

  Raises `Ecto.NoResultsError` if the Data structure does not exist.

  ## Examples

      iex> get_data_structure!(123)
      %DataStructure{}

      iex> get_data_structure!(456)
      ** (Ecto.NoResultsError)

  """
  def get_data_structure!(id) do
    DataStructure
    |> Repo.get!(id)
    |> Repo.preload(:system)
  end

  def get_data_structure_version!(data_structure_id, version) do
    attrs = %{data_structure_id: data_structure_id, version: version}

    DataStructureVersion
    |> Repo.get_by!(attrs)
    |> Repo.preload(:data_structure)
  end

  def get_data_structure_with_fields!(data_structure_id) do
    data_structure_id
    |> get_data_structure!
    |> with_latest_fields
  end

  def get_latest_fields(data_structure_id) do
    data_structure_id
    |> get_latest_version
    |> get_fields
  end

  def get_fields(data_structure_version) do
    data_structure_version
    |> Ecto.assoc(:data_fields)
    |> Repo.all()
  end

  def get_latest_children(data_structure_id) do
    data_structure_id
    |> get_latest_version
    |> get_children
  end

  def get_children(data_structure_version) do
    data_structure_version
    |> Ecto.assoc(:children)
    |> Repo.all()
    |> Repo.preload(data_structure: [:system])
    |> Enum.map(& &1.data_structure)
  end

  def get_latest_parents(data_structure_id) do
    data_structure_id
    |> get_latest_version
    |> get_parents
  end

  def get_parents(data_structure_version) do
    data_structure_version
    |> Ecto.assoc(:parents)
    |> Repo.all()
    |> Repo.preload(:data_structure)
    |> Enum.map(& &1.data_structure)
  end

  def get_latest_siblings(data_structure_id) do
    data_structure_id
    |> get_latest_version
    |> get_siblings
  end

  def get_siblings(data_structure_version) do
    data_structure_version
    |> Ecto.assoc(:parents)
    |> Repo.all()
    |> Enum.flat_map(&get_children/1)
    |> Enum.uniq()
  end

  def get_versions(%DataStructureVersion{} = dsv) do
    dsv
    |> Ecto.assoc([:data_structure, :versions])
    |> Repo.all()
  end

  def with_versions(%DataStructure{} = data_structure) do
    data_structure
    |> Repo.preload(:versions)
  end

  def with_latest_fields(%{id: id} = data_structure) do
    fields = get_latest_fields(id)

    data_structure
    |> Map.put(:data_fields, fields)
  end

  def with_latest_children(%{id: id} = data_structure) do
    children = get_latest_children(id)

    data_structure
    |> Map.put(:children, children)
  end

  def with_latest_parents(%{id: id} = data_structure) do
    parents = get_latest_parents(id)

    data_structure
    |> Map.put(:parents, parents)
  end

  def with_latest_siblings(%{id: id} = data_structure) do
    siblings = get_latest_siblings(id)

    data_structure
    |> Map.put(:siblings, siblings)
  end

  @doc """
  Creates a data_structure.

  ## Examples

      iex> create_data_structure(%{field: value})
      {:ok, %DataStructure{}}

      iex> create_data_structure(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_data_structure(attrs \\ %{}) do
    result =
      %DataStructure{}
      |> DataStructure.changeset(attrs)
      |> Repo.insert()

    case result do
      {:ok, data_structure} ->
        %DataStructureVersion{data_structure_id: data_structure.id, version: 0}
        |> Repo.insert()

        data_structure
        |> with_latest_fields
        |> @search_service.put_search

        {:ok, data_structure |> Repo.preload(:system)}

      _ ->
        result
    end
  end

  @doc """
  Updates a data_structure.

  ## Examples

      iex> update_data_structure(data_structure, %{field: new_value})
      {:ok, %DataStructure{}}

      iex> update_data_structure(data_structure, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_data_structure(
        %DataStructure{type: type} = data_structure,
        %{"df_content" => content} = attrs
      )
      when not is_nil(content) do
    case @df_cache.get_template_by_name(type) do
      %{:content => content_schema} ->
        content_changeset = Validation.build_changeset(content, content_schema)

        case content_changeset.valid? do
          false -> {:error, content_changeset}
          _ -> do_update_data_structure(data_structure, attrs)
        end

      _ ->
        {:error, "Invalid template"}
    end
  end

  def update_data_structure(%DataStructure{} = data_structure, attrs) do
    do_update_data_structure(data_structure, attrs)
  end

  defp do_update_data_structure(%DataStructure{} = data_structure, attrs) do
    result =
      data_structure
      |> DataStructure.update_changeset(attrs)
      |> Repo.update()

    case result do
      {:ok, data_structure} ->
        data_structure
        |> with_latest_fields
        |> @search_service.put_search

        result

      _ ->
        result
    end
  end

  @doc """
  Deletes a DataStructure.

  ## Examples

      iex> delete_data_structure(data_structure)
      {:ok, %DataStructure{}}

      iex> delete_data_structure(data_structure)
      {:error, %Ecto.Changeset{}}

  """
  def delete_data_structure(%DataStructure{} = data_structure) do
    result = Repo.delete(data_structure)

    case result do
      {:ok, data_structure} ->
        @search_service.delete_search(data_structure)
        result

      _ ->
        result
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking data_structure changes.

  ## Examples

      iex> change_data_structure(data_structure)
      %Ecto.Changeset{source: %DataStructure{}}

  """
  def change_data_structure(%DataStructure{} = data_structure) do
    DataStructure.changeset(data_structure, %{})
  end

  alias TdDd.DataStructures.DataField

  @doc """
  Returns the list of data_fields.

  ## Examples

      iex> list_data_fields()
      [%DataField{}, ...]

  """
  def list_data_fields do
    import Ecto.Query, only: [from: 2]
    Repo.all(from(f in DataField, order_by: [desc: f.id]))
  end

  @doc """
  Returns the list of data_structure versions for a given data structure id;

  ## Examples

      iex> list_data_structure_versions(1)
      [%DataStructureVersion{}, ...]

  """
  def list_data_structure_versions(data_structure_id) do
    Repo.all(from(v in DataStructureVersion, where: v.data_structure_id == ^data_structure_id))
  end

  @doc """
  Returns the latest data_structure version for a given data structure id;

  ## Examples

      iex> get_latest_version(1)
      %DataStructureVersion{}

  """
  def get_latest_version(data_structure_id) do
    case list_data_structure_versions(data_structure_id) do
      [] -> nil
      vs -> vs |> Enum.max_by(& &1.version)
    end
  end

  @doc """
  Returns the list of data_structure fields .

  ## Examples

      iex> list_data_structure_fields(%DataStructureVersion{})
      [%DataField{}, ...]

  """
  def list_data_structure_fields(data_structure_version) do
    Repo.all(Ecto.assoc(data_structure_version, :data_fields))
  end

  @doc """
  Gets a single data_field.

  Raises `Ecto.NoResultsError` if the Data field does not exist.

  ## Examples

      iex> get_data_field!(123)
      %DataField{}

      iex> get_data_field!(456)
      ** (Ecto.NoResultsError)

  """
  def get_data_field!(id), do: Repo.get!(DataField, id)

  @doc """
  Creates a data_field.

  ## Examples

      iex> create_data_field(%{field: value})
      {:ok, %DataField{}}

      iex> create_data_field(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_data_field(attrs \\ %{}) do
    result =
      %DataField{}
      |> DataField.changeset(attrs)
      |> Repo.insert()

    case result do
      {:ok, data_field} ->
        case Map.get(attrs, "data_structure_id") do
          nil ->
            result

          data_structure_id ->
            add_data_field(data_structure_id, data_field)
            result
        end

        # TODO: Reindex versions
        # @search_service.put_search(get_data_structure_with_fields!(data_field.data_structure_id))
        result

      _ ->
        result
    end
  end

  defp add_data_field(data_structure_id, %{id: field_id}) do
    version_id =
      data_structure_id
      |> get_or_create_version
      |> Map.get(:id)

    entries = [%{data_structure_version_id: version_id, data_field_id: field_id}]
    Repo.insert_all("versions_fields", entries)
  end

  defp get_or_create_version(data_structure_id) do
    case get_latest_version(data_structure_id) do
      nil ->
        {:ok, v} =
          %DataStructureVersion{}
          |> DataStructureVersion.changeset(%{data_structure_id: data_structure_id})
          |> Repo.insert()

        v

      v ->
        v
    end
  end

  @doc """
  Updates a data_field.

  ## Examples

      iex> update_data_field(data_field, %{field: new_value})
      {:ok, %DataField{}}

      iex> update_data_field(data_field, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_data_field(%DataField{} = data_field, attrs) do
    result =
      data_field
      |> DataField.update_changeset(attrs)
      |> Repo.update()

    case result do
      {:ok, _data_field} ->
        # TODO: Reindex affected data structure versions
        result

      _ ->
        result
    end
  end

  @doc """
  Deletes a DataField.

  ## Examples

      iex> delete_data_field(data_field)
      {:ok, %DataField{}}

      iex> delete_data_field(data_field)
      {:error, %Ecto.Changeset{}}

  """
  def delete_data_field(%DataField{} = data_field) do
    result = Repo.delete(data_field)

    case result do
      {:ok, _data_field} ->
        # TODO: Reindex affected data structure versions
        # @search_service.put_search(get_data_structure_with_fields!(data_structure_id, data_fields: true))
        result

      _ ->
        result
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking data_field changes.

  ## Examples

      iex> change_data_field(data_field)
      %Ecto.Changeset{source: %DataField{}}

  """
  def change_data_field(%DataField{} = data_field) do
    DataField.changeset(data_field, %{})
  end

  def add_domain_id(%{"ou" => domain_name, "domain_id" => nil} = data, domain_map) do
    data |> Map.put("domain_id", Map.get(domain_map, domain_name))
  end

  def add_domain_id(%{"ou" => domain_name, "domain_id" => ""} = data, domain_map) do
    data |> Map.put("domain_id", Map.get(domain_map, domain_name))
  end

  def add_domain_id(%{"ou" => _, "domain_id" => _} = data, _domain_map), do: data

  def add_domain_id(%{"ou" => domain_name} = data, domain_map) do
    data |> Map.put("domain_id", Map.get(domain_map, domain_name))
  end

  def add_domain_id(data, _domain_map), do: data |> Map.put("domain_id", nil)

  def find_data_structure(%{} = clauses) do
    Repo.get_by(DataStructure, clauses)
  end

  def get_version_children(data_structure_version_id) do
    DataStructureVersion
    |> Repo.get!(data_structure_version_id)
    |> Repo.preload(:children)
    |> Map.get(:children)
  end

  def get_version_parents(data_structure_version_id) do
    DataStructureVersion
    |> Repo.get!(data_structure_version_id)
    |> Repo.preload(:parents)
    |> Map.get(:parents)
  end

  def with_field_external_ids(%{data_fields: data_fields} = data_structure) do
    data_structure
    |> Map.put(
      :data_fields,
      Enum.map(data_fields, fn field ->
        external_id =
          DataFieldCache.get_external_id(
            data_structure.system.name,
            data_structure.group,
            data_structure.name,
            field.name
          )

        Map.put(field, :external_id, external_id)
      end)
    )
  end

  def with_field_links(%{data_fields: data_fields} = data_structure) do
    data_structure
    |> Map.put(
      :data_fields,
      Enum.map(data_fields, fn field ->
        Map.put(field, :bc_related, RelationCache.get_resources(field.id, "data_field"))
      end)
    )
  end
end
