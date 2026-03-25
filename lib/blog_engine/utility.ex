defmodule BlogEngine.Utility do
  import Ecto.Query
  alias Ecto.Repo

  defp get_repo do
    config = Application.get_env(:blue_potion, :repo)

    if config == nil do
      Module.concat([Application.get_env(:blue_potion, :otp_app), "Repo"])
    else
      config
    end
  end

  @doc """
  Gets schema information for a given module including its fields and their types.
  """
  def get_schema_info(module) when is_atom(module) do
    with {:module, cmodule} <- Code.ensure_compiled(module) |> IO.inspect(),
         {:ok, function_exported?(cmodule, :__schema__, 1)} |> IO.inspect() do
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
      |> IO.inspect()
      |> Enum.filter(&Code.ensure_compiled?(&1))
      |> IO.inspect()
      |> List.first()

    mod
  end

  def build_datatable_query(module, params, opts \\ %{}) do
    repo = get_repo()

    additional_joins =
      case Map.get(opts, "additional_joins", "") do
        "" -> []
        _ -> Map.get(opts, "additional_joins", "") |> Jason.decode!()
      end
      |> IO.inspect(label: "additional_joins")

    additional_search =
      case Map.get(opts, "additional_search", "") do
        "" -> []
        _ -> Map.get(opts, "additional_search", "") |> Jason.decode!()
      end
      |> IO.inspect(label: "additional_search")

    additional_order =
      case Map.get(opts, "additional_order", "") do
        "" -> []
        _ -> Map.get(opts, "additional_order", "") |> Jason.decode!()
      end

    preloads =
      case Map.get(opts, "preloads", []) do
        [] ->
          []

        _ ->
          Map.get(opts, "preloads", [])
          |> Jason.decode!()
          |> Enum.map(&(&1 |> BluePotion.convert_to_atom()))
      end
      |> List.flatten()
      |> IO.inspect(label: "preloads")

    parseInteger = fn value ->
      case value do
        nil -> 0
        value when is_binary(value) -> String.to_integer(value)
        value -> value
      end
    end

    # Extract DataTables parameters
    limit = parseInteger.(params["length"] || "10")
    offset = parseInteger.(params["start"] || "0")
    draw = parseInteger.(params["draw"] || "1")

    # Build base query
    base_query = from(a in module, order_by: [desc: a.id])

    # Apply joins if provided
    base_query =
      if additional_joins != "",
        do: apply_dynamic_joins(base_query, additional_joins),
        else: base_query

    # Apply additional search conditions
    base_query =
      if additional_search != "",
        do: apply_dynamic_search(base_query, additional_search),
        else: base_query

    base_query =
      if additional_order != "" do
        apply_dynamic_order(base_query, additional_order)
      else
        base_query
      end

    # Get total count before pagination
    total_query = base_query |> IO.inspect(label: "total_query")
    total_count = repo.aggregate(total_query, :count, :id)

    # Apply pagination and ordering
    final_query =
      base_query
      |> limit(^limit)
      |> offset(^offset)
      |> preload(^preloads)
      |> IO.inspect()

    # Execute query
    data = repo.all(final_query)

    sanitize_pw = fn childData ->
      if module ==
           Module.concat([Application.get_env(:blue_potion, :otp_app), "Settings", "Sale"]) do
        childData
        |> Map.delete(:registration_details)

        # |> Map.put(
        #     :registration_details,
        #     childData.registration_details
        #     |> Jason.decode!()
        #     |> Kernel.get_and_update_in(["user", "password"], &{&1, ""})
        #     |> elem(1)
        #     |> Jason.encode!()
        #   )
      else
        childData
      end
    end

    data = data |> Enum.map(&sanitize_pw.(&1))

    %{
      data: data |> BluePotion.sanitize_struct(),
      recordsTotal: total_count,
      recordsFiltered: total_count,
      draw: draw
    }
  end

  # --------------------------
  # Dynamic Query Helpers
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

      inner_join_statements =
        """
        import Ecto.Query

        acc
        |> where( [a, b, c, d, e],  #{search_value} )
        """
        |> IO.inspect(label: "inner_join_statements")

      {result, _} = Code.eval_string(inner_join_statements, acc: acc)
      result
    end

    Enum.reduce(search_statements, query, &process_search.(&1, &2))
    |> IO.inspect(label: "search_statements")
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
          IO.inspect(is_map(file_plug))
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
