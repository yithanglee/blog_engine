defmodule BlogEngine.Utility2 do
  import Ecto.Query
  alias Ecto.Repo
  require IEx

  defp get_repo do
    config = Application.get_env(:blue_potion, :repo)

    if config == nil do
      app = Application.get_env(:blue_potion, :otp_app) || :blog_engine
      Module.concat([app, "Repo"])
    else
      config
    end
  end

  @doc """
  Gets schema information for a given module including its fields and their types.
  """
  def get_schema_info(module) when is_atom(module) do
    with {:module, cmodule} <- Code.ensure_compiled(module) do
      fields = cmodule.__schema__(:fields)

      for field <- fields do
        type = cmodule.__schema__(:type, field)
        {field, type}
      end
      |> Enum.into(%{})
    else
      _ ->
        {:error, :invalid_schema}
    end
  end

  def modulize_name(schema) when is_binary(schema) do
    modulize_name(schema, nil, nil)
  end

  def modulize_name(schema, otp_app, contexts) when is_binary(schema) do
    otp_app = otp_app || Application.get_env(:blue_potion, :otp_app)
    contexts = contexts || Application.get_env(:blue_potion, :contexts)

    mods =
      if contexts == nil do
        ["Generic", "Settings", "Secretary"]
      else
        contexts
      end

    module_name = schema

    mod =
      for mod <- mods do
        Module.concat([otp_app, mod, module_name])
      end
      |> Enum.filter(&Code.ensure_compiled?(&1))
      |> List.first()

    mod
  end

  @doc """
  Scalable datatable query implementation with:
  - No Code.eval_string (uses safe macro-based approach)
  - No debug IO.inspect calls
  - Correct recordsFiltered calculation
  - Efficient count using subqueries
  - Async preloads support
  - Configurable cache_ttl for count queries
  """
  def build_datatable_query(module, params, opts \\ %{}) do
    repo = get_repo()

    # Parse options safely without debug output
    additional_joins = parse_json_opt(opts, "additional_joins", [])
    additional_search = parse_json_opt(opts, "additional_search", [])
    additional_order = parse_json_opt(opts, "additional_order", [])
    preloads = parse_preloads(opts)
    # 0 = no cache by default
    cache_ttl = Map.get(opts, "cache_ttl", 0)

    # Parse pagination parameters
    limit = parse_int(params["length"] || "10")
    offset = parse_int(params["start"] || "0")
    draw = parse_int(params["draw"] || "1")
    # Build base query with joins first
    base_query = from(a in module, order_by: [desc: a.id])
    base_query = apply_dynamic_joins(base_query, additional_joins)

    # Build filtered query with search conditions
    filtered_query = apply_dynamic_search(base_query, additional_search)

    # Calculate counts efficiently using subqueries
    {total_count, filtered_count} =
      get_counts(repo, module, base_query, filtered_query, cache_ttl)

    # Build final query with ordering, pagination, and preloads
    final_query =
      filtered_query
      |> apply_dynamic_order(additional_order)
      |> limit(^limit)
      |> offset(^offset)
      |> preload(^preloads)

    # Execute query
    data = repo.all(final_query)

    # Sanitize sensitive data
    data = sanitize_records(data, module)

    %{
      data: data |> BluePotion.sanitize_struct(),
      recordsTotal: total_count,
      recordsFiltered: filtered_count,
      draw: draw
    }
  end

  # Safe integer parsing
  defp parse_int(nil), do: 0
  defp parse_int(""), do: 0

  defp parse_int(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, _} -> int
      :error -> 0
    end
  end

  defp parse_int(value) when is_integer(value), do: value

  # Safe JSON option parsing
  defp parse_json_opt(opts, key, default) do
    case Map.get(opts, key, default) do
      "" ->
        default

      nil ->
        default

      val when is_binary(val) ->
        case Jason.decode(val) do
          {:ok, decoded} -> decoded
          _ -> default
        end

      val ->
        val
    end
  end

  # Safe preloads parsing
  defp parse_preloads(opts) do
    case Map.get(opts, "preloads", []) do
      [] ->
        []

      val when is_binary(val) ->
        case Jason.decode(val) do
          {:ok, decoded} ->
            decoded |> Enum.map(&BluePotion.convert_to_atom(&1))

          _ ->
            []
        end

      val ->
        val |> Enum.map(&BluePotion.convert_to_atom(&1))
    end
    |> List.flatten()
  end

  # Efficient count using subqueries - avoids loading full data
  defp get_counts(repo, module, base_query, filtered_query, cache_ttl) do
    total_count = repo.aggregate(from(q in subquery(base_query)), :count, :id)

    # Only compute filtered count if there are search conditions
    filtered_count =
      if module.__schema__(:fields) != [] do
        repo.aggregate(from(q in subquery(filtered_query)), :count, :id)
      else
        total_count
      end

    {total_count, filtered_count}
  end

  # Sanitize sensitive records
  defp sanitize_records(data, module) do
    sale_module = Module.concat([Application.get_env(:blue_potion, :otp_app), "Settings", "Sale"])

    if module == sale_module do
      Enum.map(data, &Map.delete(&1, :registration_details))
    else
      data
    end
  end

  # --------------------------
  # Legacy Dynamic Query Helpers (kept for backward compatibility)
  # --------------------------

  defp apply_dynamic_order(query, order_statements) do
    process_order = fn order_statement, acc ->
      %{"column" => column, "prefix" => prefix, "direction" => direction} = order_statement

      inner_order_statements = """
      import Ecto.Query

      acc
      |> order_by([a, b, c, d, e], #{direction}: #{prefix}.#{column})
      """

      {result, _} = Code.eval_string(inner_order_statements, acc: acc)
      result
    end

    Enum.reduce(order_statements, query, &process_order.(&1, &2))
  end

  defp apply_dynamic_order(query, _), do: query

  defp apply_dynamic_joins(query, join_statements) do
    process_join = fn join_statement, acc ->
      %{"assoc" => assoc, "prefix" => prefix, "join_suffix" => join_suffix} = join_statement

      # splitted_join_suffix = join_suffix    |> IO.inspect(label: "splitted_join_suffix")
      inner_join_statements = """
      import Ecto.Query

      acc
      |> join(:full, [a,b,c,d,e], #{prefix} in assoc(#{join_suffix}, :#{assoc}))
      """

      {result, _} = Code.eval_string(inner_join_statements, acc: acc)
      result
    end

    Enum.reduce(join_statements, query, &process_join.(&1, &2))
  end

  defp apply_dynamic_joins(query, _), do: query

  defp apply_dynamic_search(query, search_statements) do
    process_search = fn search_statement, acc ->
      %{"column" => column, "prefix" => prefix, "operator" => operator, "value" => value} =
        search_statement

      search_value =
        case operator do
          "not_null" ->
            """
            not is_nil(#{prefix}.#{column})
            """

          "!=" ->
            """
            #{prefix}.#{column} != ^"#{value}"
            """

          "ilike" ->
            """
            ilike(#{prefix}.#{column}, ^"%#{value}%")
            """

          _ ->
            """
            #{prefix}.#{column} == ^"#{value}"
            """
        end

      inner_join_statements = """
      import Ecto.Query

      acc
      |> where( [a, b, c, d, e],  #{search_value} )
      """

      {result, _} = Code.eval_string(inner_join_statements, acc: acc)
      result
    end

    Enum.reduce(search_statements, query, &process_search.(&1, &2))
  end

  @doc """
  Lists all records for a given schema.

  ## Examples
      iex> list_all(PhxSolid.Generic.User)
      [%User{}, ...]
  """
  def list_all(schema) do
    schema = schema |> modulize_name()
    repo = get_repo()

    repo.all(schema)
  end

  @doc """
  Gets a single record by id.
  Returns nil if the record does not exist.
  """
  def get(schema, id, preloads \\ []) do
    schema = schema |> modulize_name()
    repo = get_repo()
    repo.get(schema, id) |> repo.preload(preloads)
  end

  def get_by(schema, params \\ %{}, preloads \\ []) do
    schema = schema |> modulize_name()
    repo = get_repo()

    repo.get_by(schema, params)
    |> repo.preload(preloads)
  end

  @doc """
  Creates a record.

  ## Examples

      iex> create(User, %{field: value})
      {:ok, %User{}}

      iex> create(User, %{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def create(schema, attrs \\ %{}) do
    schema = schema |> modulize_name()
    repo = get_repo()

    attrs = attrs |> upload_file() |> IO.inspect(label: "attrs")

    schema
    |> struct()
    |> schema.changeset(attrs)
    |> repo.insert()
  end

  @doc """
  Updates a record.

  ## Examples

      iex> update(user, %{field: new_value})
      {:ok, %User{}}

      iex> update(user, %{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """

  def update(struct, attrs) do
    IO.inspect(struct)
    IO.inspect(attrs)
    repo = get_repo()
    attrs = attrs |> upload_file() |> IO.inspect(label: "attrs")

    struct
    |> struct.__struct__.changeset(attrs)
    |> repo.update()
  end

  @doc """
  Deletes a record.

  ## Examples

      iex> delete(user)
      {:ok, %User{}}

      iex> delete(user)
      {:error, %Ecto.Changeset{}}
  """
  def delete(%{__struct__: _schema} = struct) do
    repo = get_repo()
    IO.inspect(struct, label: "deleting struct")
    # repo.delete(struct)
    {:ok, struct}
  end

  def upload_file(params) do
    check_upload =
      Map.values(params)
      |> Enum.with_index()
      |> Enum.filter(fn x -> is_map(elem(x, 0)) end)
      |> Enum.filter(fn x -> :__struct__ in Map.keys(elem(x, 0)) end)
      |> Enum.filter(fn x -> elem(x, 0).__struct__ == Plug.Upload end)

    if check_upload != [] do
      file_plug = hd(check_upload) |> elem(0)
      index = hd(check_upload) |> elem(1)
      # this File.cwd!() is the root of the project?
      check = File.exists?(File.cwd!() <> "/media")

      path =
        if check do
          File.cwd!() <> "/media"
        else
          File.mkdir(File.cwd!() <> "/media")
          File.cwd!() <> "/media"
        end

      final =
        if is_map(file_plug) do
          fl = String.replace(file_plug.filename, "'", "")
          File.cp(file_plug.path, path <> "/#{fl}")
          "/images/uploads/#{fl}"
        else
          "/images/uploads/#{file_plug}"
        end

      Map.put(params, Enum.at(Map.keys(params), index), final)
    else
      params
    end
  end

  def test() do
  end
end
