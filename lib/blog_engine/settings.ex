defmodule BlogEngine.Settings do
  @moduledoc """
  The Settings context.
  """
  require Logger
  # import Mogrify
  import Ecto.Query, warn: false
  alias BlogEngine.Repo
  require IEx
  alias Ecto.Multi
  alias BlogEngine.Settings.DeviceTimeLog

  def append_bool_key(params, bool_key) do
    eval_true_bool = fn ->
      case Map.get(params, bool_key) do
        "on" -> true
        "true" -> true
        _ -> false
      end
    end

    if bool_key in Map.keys(params) do
      params |> Map.put(bool_key, eval_true_bool.())
    else
      params |> Map.put(bool_key, false)
      # params
    end
  end

  alias BlogEngine.Settings.Organization

  def list_organizations() do
    Repo.all(Organization)
  end

  def get_organization!(id) do
    Repo.get!(Organization, id)
  end

  @doc """
  Loads `tnc` for an organization. Valid UTF-8 bytes are returned as a string; otherwise Base64
  so the payload is JSON-safe.
  """
  def fetch_organization_tnc(organization_id) when is_integer(organization_id) do
    case Repo.get(Organization, organization_id) do
      nil ->
        {:error, "Organization not found"}

      %Organization{tnc: tnc} ->
        tnc_out =
          case tnc do
            nil ->
              nil

            <<>> ->
              nil

            bin when is_binary(bin) ->
              if String.valid?(bin), do: bin, else: Base.encode64(bin)
          end

        {:ok, %{tnc: tnc_out}}
    end
  end

  def create_organization(params \\ %{}) do
    Organization.changeset(%Organization{}, params) |> Repo.insert() |> IO.inspect()
  end

  def update_organization(model, params) do
    case Organization.changeset(model, params) |> Repo.update() do
      {:ok, organization} = res ->
        if url = organization.service_account_url do
          filename = Path.basename(url)
          media_path = Path.join([File.cwd!(), "media", filename])

          if File.exists?(media_path) do
            profile_name =
              organization.name
              |> String.downcase()
              |> String.replace(~r/[^a-z0-9_-]/, "")

            if profile_name != "" do
              dest_dir =
                Path.join([
                  Application.app_dir(:blog_engine),
                  "priv/static/firebase",
                  profile_name
                ])

              File.mkdir_p!(dest_dir)
              File.cp!(media_path, Path.join(dest_dir, "service-account.json"))
              BlogEngine.Fcm.start_or_restart_profile(profile_name)
            end
          end
        end

        res

      other ->
        other
    end
  end

  def delete_organization(%Organization{} = model) do
    Repo.delete(model)
  end

  def list_device_time_logs() do
    Repo.all(DeviceTimeLog)
  end

  def get_device_time_log!(id) do
    Repo.get!(DeviceTimeLog, id)
  end

  def create_device_time_log(params \\ %{}) do
    # here probably use a kv master to store their last online time?
    res = DeviceTimeLog.changeset(%DeviceTimeLog{}, params) |> Repo.insert()

    case res do
      {:ok, dtl} ->
        IO.inspect(dtl)
        DeviceTracker.update_last_online(dtl.device_id)

      _ ->
        nil
    end

    res
  end

  def update_device_time_log(model, params) do
    DeviceTimeLog.changeset(model, params) |> Repo.update()
  end

  def delete_device_time_log(%DeviceTimeLog{} = model) do
    Repo.delete(model)
  end

  alias BlogEngine.Settings.DeviceLog

  def list_device_logs() do
    Repo.all(DeviceLog)
  end

  def get_device_log!(id) do
    Repo.get!(DeviceLog, id)
  end

  def create_device_log(params \\ %{}) do
    DeviceLog.changeset(%DeviceLog{}, params) |> Repo.insert() |> IO.inspect()
  end

  def update_device_log(model, params) do
    DeviceLog.changeset(model, params) |> Repo.update() |> IO.inspect()
  end

  def delete_all_device_log(device_id) do
    Repo.delete_all(from(d in DeviceLog, where: d.device_id == ^device_id))
  end

  def delete_device_log(%DeviceLog{} = model) do
    Repo.delete(model)
  end

  alias BlogEngine.Settings.Outlet

  def list_outlets() do
    Repo.all(Outlet)
  end

  def list_outlets_by_organization(organization_id) do
    Repo.all(from(o in Outlet, where: o.organization_id == ^organization_id))
  end

  def get_outlet_by_subdomain(id) do
    Repo.get_by(Outlet, subdomain: id)
  end

  def get_outlet_by_uid(id) do
    Repo.get_by(Outlet, uid: id)
  end

  def get_outlet!(id) do
    Repo.get!(Outlet, id)
  end

  def create_outlet(params \\ %{}) do
    Outlet.changeset(%Outlet{}, params) |> Repo.insert() |> IO.inspect()
  end

  def update_outlet(model, params) do
    Outlet.changeset(model, params) |> Repo.update() |> IO.inspect()
  end

  def delete_outlet(%Outlet{} = model) do
    Repo.delete(model)
  end

  alias BlogEngine.Settings.Sale

  def list_sales() do
    Repo.all(Sale)
  end

  def get_sale_by_payment_ref(id) do
    Repo.all(from(s in Sale, where: s.payment_ref == ^id, preload: [:device, :sales_items]))
    |> List.first()
  end

  def get_sale!(id) do
    Repo.get!(Sale, id) |> Repo.preload([:outlet, :device, sales_items: [:item]])
  end

  def create_sale(params \\ %{}) do
    Sale.changeset(%Sale{}, params) |> Repo.insert() |> IO.inspect()
  end

  def update_sale(model, params) do
    Sale.changeset(model, params) |> Repo.update() |> IO.inspect()
  end

  def delete_sale(%Sale{} = model) do
    si = model |> Repo.preload(:sales_items) |> Map.get(:sales_items)

    for item <- si do
      Repo.delete(item)
    end

    Repo.delete(model)
  end

  alias BlogEngine.Settings.Item

  def list_items() do
    Repo.all(Item)
  end

  def list_items_by_device(name) do
    Repo.all(
      from(i in Item,
        left_join: o in BlogEngine.Settings.Outlet,
        on: o.id == i.outlet_id,
        left_join: d in BlogEngine.Settings.Device,
        on: d.outlet_id == o.id,
        where: d.name == ^name
      )
    )
  end

  def list_items_by_subdomain(code) do
    Repo.all(
      from(i in Item,
        left_join: o in BlogEngine.Settings.Outlet,
        on: o.id == i.outlet_id,
        where: o.subdomain == ^code
      )
    )
  end

  def get_item!(id) do
    Repo.get!(Item, id) |> Repo.preload(:outlet)
  end

  def create_item(params \\ %{}) do
    Item.changeset(%Item{}, params) |> Repo.insert() |> IO.inspect()
  end

  def update_item(model, params) do
    Item.changeset(model, params) |> Repo.update() |> IO.inspect()
  end

  def delete_item(%Item{} = model) do
    Repo.delete(model)
  end

  alias BlogEngine.Settings.SalesItem

  def list_sales_items() do
    Repo.all(SalesItem)
  end

  def get_sales_item!(id) do
    Repo.get!(SalesItem, id)
  end

  def create_sales_item(params \\ %{}) do
    SalesItem.changeset(%SalesItem{}, params) |> Repo.insert() |> IO.inspect()
  end

  def update_sales_item(model, params) do
    SalesItem.changeset(model, params) |> Repo.update() |> IO.inspect()
  end

  def delete_sales_item(%SalesItem{} = model) do
    Repo.delete(model)
  end

  alias BlogEngine.Settings.Device

  def list_devices() do
    Repo.all(Device)
  end

  def get_device_by_short_name(id) do
    Repo.all(from(d in Device, where: ilike(d.short_name, ^"%#{id}%"), preload: [:outlet]))
    |> List.first()
  end

  def get_device_by_name(id) do
    Repo.get_by(Device, name: id) |> Repo.preload(:outlet)
  end

  def get_device(id) do
    case Repo.get(Device, id) do
      {:ok, device} ->
        device |> Repo.preload([:outlet, :organization])

      _ ->
        nil
    end
  end

  def get_device!(id) do
    Repo.get!(Device, id) |> Repo.preload([:outlet, :organization])
  end

  def create_update_device(params \\ %{}) do
    device = get_device_by_name(params |> Map.get("user_id"))

    if device == nil do
      {:ok, dev} =
        Device.changeset(%Device{}, %{"name" => params |> Map.get("user_id")}) |> Repo.insert()

      dev
    else
      device
    end
  end

  def create_device(params \\ %{}) do
    res = Device.changeset(%Device{}, params) |> Repo.insert() |> IO.inspect()

    case res do
      {:ok, d} ->
        # CloridgeAPI.initial_setup(d.cloridge_device_uid)
        nil

      _ ->
        nil
    end

    res
  end

  def update_device(model, params) do
    dcg = Device.changeset(model, params) |> Repo.update() |> IO.inspect()

    case dcg do
      {:ok, d} ->
        is_bill_acceptor = fn ->
          if d.is_rs232 do
            "bill_acceptor"
          else
            "pwm_machine"
          end
        end

        BlogEngineWeb.Endpoint.broadcast("user:#{d.name}", "settings_response", %{
          "rs232_config" => %{"device_type" => is_bill_acceptor.()},
          "pwm_config" => %{"input_pin" => d.reading_pin}
        })

        Cachex.del(:device_blocked_cache, d.name)

      _ ->
        nil
    end

    dcg
  end

  def delete_device(%Device{} = model) do
    Repo.delete_all(from(s in BlogEngine.Settings.IoReading, where: s.device_id == ^model.id))
    pid = Process.whereis(:device_cache)

    if pid do
      Agent.update(pid, fn cache -> Map.delete(cache, model.name) end)
    end

    Repo.delete(model)
  end

  alias BlogEngine.Settings.Slide

  def list_slides(is_show) do
    Repo.all(from(s in Slide, where: s.is_show == ^is_show))
  end

  def get_slide!(id) do
    Repo.get!(Slide, id)
  end

  def create_slide(params \\ %{}) do
    Slide.changeset(%Slide{}, params) |> Repo.insert() |> IO.inspect()
  end

  def update_slide(model, params) do
    Slide.changeset(model, params) |> Repo.update() |> IO.inspect()
  end

  def delete_slide(%Slide{} = model) do
    Repo.delete(model)
  end

  alias BlogEngine.Settings.SessionUser

  def get_member_by_cookie(cookie) do
    Repo.all(from(s in SessionUser, where: s.cookie == ^cookie))
    |> List.first()
  end

  def get_cookie_user_by_cookie(cookie) when is_binary(cookie) and cookie != "" do
    member_session =
      with {:ok, %{id: id}} <-
             Phoenix.Token.verify(BlogEngineWeb.Endpoint, "member_signature", cookie),
           %BlogEngine.Settings.User{} = user <-
             Repo.get(BlogEngine.Settings.User, id)
             |> Repo.preload([:organization]) do
        %{cookie: cookie, user: user}
      else
        _ -> nil
      end

    if member_session != nil do
      member_session
    else
      admin_session =
        with {:ok, username} <-
               Phoenix.Token.verify(BlogEngineWeb.Endpoint, "admin_signature", cookie),
             true <- is_binary(username),
             staff when not is_nil(staff) <- get_staff_by_username(username) do
          staff = Repo.preload(staff, [:organization, role: :app_routes])
          %{cookie: cookie, user: staff}
        else
          _ -> nil
        end

      if admin_session != nil do
        admin_session
      else
        Repo.one(
          from(s in SessionUser,
            where: s.cookie == ^cookie,
            preload: [user: [:organization, role: :app_routes]]
          )
        )
      end
    end
  end

  def get_cookie_user_by_cookie(_), do: nil

  @session_refresh_max_age 60 * 60 * 24 * 365

  @doc """
  Re-issues a session token when the current one has expired but is still within
  the refresh window (matches client cookie lifetime). Returns `{:error, :expired}`
  when the session cannot be recovered.
  """
  def refresh_session_by_cookie(cookie) when is_binary(cookie) and cookie != "" do
    case get_cookie_user_by_cookie(cookie) do
      %{cookie: c, user: u} ->
        {:ok, %{cookie: c, user: u, refreshed: false}}

      _ ->
        refresh_expired_session(cookie)
    end
  end

  def refresh_session_by_cookie(_), do: {:error, :expired}

  defp refresh_expired_session(cookie) do
    case Phoenix.Token.verify(
           BlogEngineWeb.Endpoint,
           "member_signature",
           cookie,
           max_age: @session_refresh_max_age
         ) do
      {:ok, %{id: id}} ->
        case Repo.get(BlogEngine.Settings.User, id) |> Repo.preload([:organization]) do
          %BlogEngine.Settings.User{} = user -> issue_member_session(user)
          _ -> try_session_user_row(cookie)
        end

      {:error, _} ->
        case Phoenix.Token.verify(
               BlogEngineWeb.Endpoint,
               "admin_signature",
               cookie,
               max_age: @session_refresh_max_age
             ) do
          {:ok, username} when is_binary(username) ->
            case get_staff_by_username(username) do
              staff when not is_nil(staff) -> issue_staff_session(staff)
              _ -> try_session_user_row(cookie)
            end

          {:error, _} ->
            try_session_user_row(cookie)
        end
    end
  end

  defp try_session_user_row(cookie) do
    case Repo.one(from(s in SessionUser, where: s.cookie == ^cookie)) do
      %SessionUser{user_id: user_id} ->
        cond do
          match?(%BlogEngine.Settings.User{}, user = Repo.get(BlogEngine.Settings.User, user_id)) ->
            user = user |> Repo.preload([:organization])
            issue_member_session(user)

          match?(
            %BlogEngine.Settings.Staff{},
            staff = Repo.get(BlogEngine.Settings.Staff, user_id)
          ) ->
            staff = staff |> Repo.preload([:organization, role: :app_routes])
            issue_staff_session(staff)

          true ->
            {:error, :expired}
        end

      _ ->
        {:error, :expired}
    end
  end

  defp issue_member_session(%BlogEngine.Settings.User{} = user) do
    token = member_token(user.id)
    create_session_user(%{"cookie" => token, "user_id" => user.id})
    {:ok, %{cookie: token, user: user, refreshed: true}}
  end

  defp issue_staff_session(%BlogEngine.Settings.Staff{} = staff) do
    staff = Repo.preload(staff, [:organization, role: :app_routes])

    token =
      Phoenix.Token.sign(
        BlogEngineWeb.Endpoint,
        "admin_signature",
        staff.username
      )

    create_session_user(%{"cookie" => token, "user_id" => staff.id})
    {:ok, %{cookie: token, user: staff, refreshed: true}}
  end

  def list_session_users() do
    Repo.all(SessionUser)
  end

  def get_session_user!(id) do
    Repo.get!(SessionUser, id)
  end

  def create_session_user(params \\ %{}) do
    SessionUser.changeset(%SessionUser{}, params) |> Repo.insert() |> IO.inspect()
  end

  def update_session_user(model, params) do
    SessionUser.changeset(model, params) |> Repo.update() |> IO.inspect()
  end

  def delete_session_user(%SessionUser{} = model) do
    Repo.delete(model)
  end

  alias BlogEngine.Settings.AppRoute

  def list_app_routes() do
    Repo.all(AppRoute)
  end

  def get_app_route!(id) do
    Repo.get!(AppRoute, id)
  end

  def create_app_route(params \\ %{}) do
    name = params["name"]
    check = Repo.all(from(ap in AppRoute, where: ap.name == ^name))

    if check == [] do
      cg = AppRoute.changeset(%AppRoute{}, params) |> Repo.insert() |> IO.inspect()
    else
      {:ok, List.first(check)}
    end
  end

  def update_app_route(model, params) do
    AppRoute.changeset(model, params) |> Repo.update() |> IO.inspect()
  end

  def delete_app_route(%AppRoute{} = model) do
    Repo.delete(model)
  end

  alias BlogEngine.Settings.Role

  def list_roles() do
    Repo.all(Role)
  end

  def get_role!(id) do
    Repo.get!(Role, id) |> Repo.preload(:app_routes)
  end

  def create_role(params \\ %{}) do
    Role.changeset(%Role{}, params) |> Repo.insert() |> IO.inspect()
  end

  def update_role(model, params) do
    Role.changeset(model, params) |> Repo.update() |> IO.inspect()
  end

  def delete_role(%Role{} = model) do
    Repo.delete(model)
  end

  alias BlogEngine.Settings.RoleAppRoute

  def list_role_app_routes() do
    Repo.all(RoleAppRoute)
  end

  def get_role_app_route!(id) do
    Repo.get!(RoleAppRoute, id)
  end

  def create_role_app_route(
        %{"app_route_id" => app_route_ids, "id" => "0", "role_id" => role_id} = _params
      ) do
    Repo.delete_all(from(rap in RoleAppRoute, where: rap.role_id == ^role_id))

    for app_route_id <- app_route_ids |> String.split(",") do
      params = %{"role_id" => role_id, "app_route_id" => app_route_id}
      RoleAppRoute.changeset(%RoleAppRoute{}, params) |> Repo.insert() |> IO.inspect()
    end

    {:ok, %RoleAppRoute{id: 0}}
  end

  def create_role_app_route(%{"AppRoute" => %{} = mapList, "id" => "0"} = params) do
    role_id = Map.keys(params["AppRoute"]) |> List.first()

    items = params["AppRoute"][role_id] |> Map.keys()
    Repo.delete_all(from(rap in RoleAppRoute, where: rap.role_id == ^role_id))

    for item <- items do
      params = %{"role_id" => role_id, "app_route_id" => item}
      RoleAppRoute.changeset(%RoleAppRoute{}, params) |> Repo.insert() |> IO.inspect()
    end

    {:ok, %RoleAppRoute{id: 0}}
  end

  def update_role_app_route(model, params) do
    RoleAppRoute.changeset(model, params) |> Repo.update() |> IO.inspect()
  end

  def delete_role_app_route(%RoleAppRoute{} = model) do
    Repo.delete(model)
  end

  alias BlogEngine.Settings.Staff

  def list_staffs() do
    Repo.all(Staff)
  end

  def get_staff!(id) do
    Repo.get!(Staff, id)
  end

  def create_staff(params \\ %{}) do
    Staff.changeset(%Staff{}, params) |> Repo.insert() |> IO.inspect()
  end

  def update_staff(model, attrs) do
    attrs =
      with true <- "password" in Map.keys(attrs),
           true <- attrs["password"] != "" do
        crypted_password =
          :crypto.hash(:sha512, attrs["password"]) |> Base.encode16() |> String.downcase()

        attrs |> Map.put("crypted_password", crypted_password)
      else
        _ ->
          attrs
      end

    Staff.changeset(model, attrs) |> Repo.update() |> IO.inspect()
  end

  def delete_staff(%Staff{} = model) do
    Repo.delete(model)
  end

  alias BlogEngine.Settings.Announcement

  def list_announcements() do
    Repo.all(Announcement)
  end

  def get_announcement!(id) do
    Repo.get!(Announcement, id)
  end

  def create_announcement(params \\ %{}) do
    Announcement.changeset(%Announcement{}, params) |> Repo.insert() |> IO.inspect()
  end

  def update_announcement(model, params) do
    Announcement.changeset(model, params) |> Repo.update() |> IO.inspect()
  end

  def delete_announcement(%Announcement{} = model) do
    Repo.delete(model)
  end

  alias BlogEngine.Settings.User

  def member_token(id) do
    Repo.delete_all(from(su in BlogEngine.Settings.SessionUser, where: su.user_id == ^id))

    Phoenix.Token.sign(
      BlogEngineWeb.Endpoint,
      "member_signature",
      %{id: id}
    )
  end

  def decode_admin_token(token) do
    case Phoenix.Token.verify(BlogEngineWeb.Endpoint, "admin_signature", token) do
      {:ok, map} ->
        map

      {:error, _reason} ->
        nil
    end
  end

  def decode_token(token) do
    case Phoenix.Token.verify(BlogEngineWeb.Endpoint, "member_signature", token) do
      {:ok, map} ->
        map

      {:error, _reason} ->
        nil
    end
  end

  def override_user(params) do
    user =
      Repo.all(from(u in User, where: u.username == ^params["username"]))
      |> List.first()

    with true <- user != nil,
         crypted_password <-
           :crypto.hash(:sha512, params["password"]) |> Base.encode16() |> String.downcase(),
         true <- crypted_password == user.temp_pin do
      {:ok, user} = User.changeset(user, %{temp_pin: nil}) |> Repo.update()
      user = user |> Repo.preload([:organization])
      {:ok, user}
    else
      _ ->
        {:error}
    end
  end

  def auth_user(params) do
    login =
      params
      |> Map.get("username", "")
      |> to_string()
      |> String.trim()

    password = Map.get(params, "password")

    user =
      cond do
        login == "" ->
          nil

        String.contains?(login, "@") ->
          get_user_by_email(login)

        true ->
          Repo.one(
            from(u in User,
              where: u.username == ^login,
              preload: [:organization]
            )
          )
      end

    with %User{} = user <- user,
         true <- is_binary(password),
         crypted_password <-
           :crypto.hash(:sha512, password) |> Base.encode16() |> String.downcase(),
         true <- crypted_password == user.crypted_password do
      {:ok, user}
    else
      _ ->
        {:error, nil}
    end
  end

  def list_users() do
    Repo.all(User)
  end

  def get_user!(id) do
    Repo.all(from(u in User, where: u.id == ^id, preload: [:organization])) |> List.first()
  end

  def create_user(attrs \\ %{}) do
    attrs =
      cond do
        Map.has_key?(attrs, "password") and is_binary(attrs["password"]) and
            String.trim(attrs["password"]) != "" ->
          crypted_password =
            :crypto.hash(:sha512, attrs["password"]) |> Base.encode16() |> String.downcase()

          attrs |> Map.put("crypted_password", crypted_password) |> Map.delete("password")

        true ->
          attrs
      end

    User.changeset(%User{}, attrs) |> Repo.insert() |> IO.inspect()
  end

  @doc """
  After a correct email PIN, creates or updates a `users` row when `send_email_pin` stored
  `:crypted_password` / `:register_name` in the pin agent (password was supplied at registration).

  Returns `{:ok, :created | :updated | :skipped}` or `{:error, reason | Ecto.Changeset}`.
  """
  def register_verified_member_from_pin(normalized_email, stored) when is_map(stored) do
    hash = Map.get(stored, :crypted_password)
    reg_name = Map.get(stored, :register_name)
    org_id = Map.get(stored, :organization_id)

    if !is_binary(hash) or (is_binary(hash) and String.trim(hash) == "") do
      {:ok, :skipped}
    else
      fullname =
        if is_binary(reg_name) and String.trim(reg_name) != "" do
          String.trim(reg_name)
        else
          normalized_email
        end

      case get_user_by_email(normalized_email) do
        nil ->
          username = unique_member_username(normalized_email)

          attrs =
            %{
              "username" => username,
              "email" => normalized_email,
              "fullname" => fullname,
              "crypted_password" => hash
            }
            |> then(fn a ->
              if is_integer(org_id), do: Map.put(a, "organization_id", org_id), else: a
            end)

          case create_user(attrs) do
            {:ok, _} -> {:ok, :created}
            {:error, cs} -> {:error, cs}
          end

        %User{} = u ->
          if u.crypted_password in [nil, ""] do
            update_attrs =
              %{crypted_password: hash, fullname: fullname}
              |> then(fn a ->
                if is_integer(org_id) and u.organization_id in [nil, 0],
                  do: Map.put(a, :organization_id, org_id),
                  else: a
              end)

            case User.changeset(u, update_attrs)
                 |> Repo.update() do
              {:ok, _} -> {:ok, :updated}
              {:error, cs} -> {:error, cs}
            end
          else
            {:error, :already_registered}
          end
      end
    end
  end

  defp unique_member_username(email) when is_binary(email) do
    local =
      email
      |> String.split("@")
      |> List.first()
      |> to_string()
      |> String.replace(~r/[^a-zA-Z0-9_]/, "_")
      |> String.slice(0, 32)

    base = if local == "", do: "user", else: local

    if get_user_by_username(base) == nil do
      base
    else
      "#{base}_#{:rand.uniform(999_999)}"
    end
  end

  @doc """
  Persists only `fcm_token` on a consumer `User`.
  Does not rotate the member session (unlike `update_user/2`, which calls `member_token/1`).
  """
  def update_user_fcm_token(%User{} = user, token) when is_binary(token) do
    user
    |> User.changeset(%{"fcm_token" => token})
    |> Repo.update()
  end

  def update_user(model, attrs) do
    attrs =
      with true <- "password" in Map.keys(attrs),
           true <- attrs["password"] != "" do
        crypted_password =
          :crypto.hash(:sha512, attrs["password"]) |> Base.encode16() |> String.downcase()

        attrs |> Map.put("crypted_password", crypted_password)
      else
        _ ->
          attrs
      end

    cg =
      Multi.new()
      |> Multi.run(:user, fn _repo, %{} ->
        User.changeset(model, attrs) |> Repo.update()
      end)
      |> Repo.transaction()
      |> IO.inspect()

    case cg do
      {:ok, multi_res} ->
        u =
          multi_res
          |> Map.get(:user)
          |> Map.put(
            :token,
            BlogEngine.Settings.member_token(multi_res |> Map.get(:user) |> Map.get(:id))
          )

        {:ok, u}

      {:error, cg} ->
        {:error, cg}
    end
  end

  def delete_user(%User{} = model) do
    Repo.delete(model)
  end

  def get_user_by_username(username) do
    Repo.get_by(User, username: username)
  end

  @doc """
  Resolves a consumer `User` in `organization_id` for staff support lookup.

  Tries case-insensitive exact `username` match first, then full match on `phone` after
  stripping non-digits from both sides (minimum 6 digits in the query).

  Returns `{:ok, %User{}}`, `{:error, :not_found}`, or `{:error, :ambiguous}` when several
  members share the same normalized phone.
  """
  def resolve_org_member_by_username_or_phone(organization_id, query)
      when is_integer(organization_id) and is_binary(query) do
    q = String.trim(query)

    cond do
      q == "" ->
        {:error, :not_found}

      true ->
        case repo_one_org_member_by_username_ci(organization_id, q) do
          %User{} = u -> {:ok, u}
          nil -> resolve_org_member_by_phone_digits(organization_id, q)
        end
    end
  end

  def resolve_org_member_by_username_or_phone(_, _), do: {:error, :not_found}

  defp repo_one_org_member_by_username_ci(organization_id, q) do
    Repo.one(
      from(u in User,
        where: u.organization_id == ^organization_id,
        where: fragment("LOWER(TRIM(?)) = LOWER(TRIM(?))", u.username, ^q)
      )
    )
  end

  defp resolve_org_member_by_phone_digits(organization_id, q) when is_binary(q) do
    digits = normalize_member_phone_digits(q)

    cond do
      digits == "" or byte_size(digits) < 6 ->
        {:error, :not_found}

      true ->
        matches =
          Repo.all(
            from(u in User,
              where: u.organization_id == ^organization_id,
              where:
                fragment(
                  "regexp_replace(coalesce(?, ''), '[^0-9]', '', 'g') = ?",
                  u.phone,
                  ^digits
                )
            )
          )

        case matches do
          [] -> {:error, :not_found}
          [%User{} = u] -> {:ok, u}
          _ -> {:error, :ambiguous}
        end
    end
  end

  defp normalize_member_phone_digits(str) when is_binary(str) do
    String.replace(str, ~r/\D/, "")
  end

  @doc """
  Looks up a member `User` by Firebase Authentication UID (stored in `firebase_auth_id`).
  """
  def get_user_by_firebase_auth_id(firebase_auth_id) when is_binary(firebase_auth_id) do
    Repo.one(
      from(u in User,
        where: u.firebase_auth_id == ^firebase_auth_id,
        preload: [:organization]
      )
    )
  end

  def get_user_by_firebase_auth_id(_), do: nil

  @doc """
  Case-insensitive email lookup for member `User` (not `Staff`).
  """
  def get_user_by_email(email) when is_binary(email) do
    e = String.trim(email)

    if e == "" do
      nil
    else
      Repo.one(
        from(u in User,
          where: fragment("LOWER(?) = LOWER(?)", u.email, ^e)
        )
      )
    end
  end

  def get_user_by_email(_), do: nil

  @doc """
  Sign in a member via Firebase Auth (email/password with verified email, or Google, etc.).

  Expects a map with string keys, e.g. `%{"uid" => ..., "email" => ..., "email_verified" => true}`.
  Links `firebase_auth_id` on first successful match by email.

  Returns `{:ok, %{user: user_map, token: cookie_token}}` or `{:error, reason}`.
  """
  def sign_in_with_firebase(attrs) when is_map(attrs) do
    attrs = for {k, v} <- attrs, into: %{}, do: {to_string(k), v}

    uid = attrs["uid"]

    cond do
      not is_binary(uid) or String.trim(uid) == "" ->
        {:error, :invalid_firebase_uid}

      true ->
        email = attrs["email"] |> normalize_firebase_email()
        email_verified = firebase_email_verified?(attrs, email)

        cond do
          is_binary(email) and email != "" and email_verified == false ->
            {:error, :email_not_verified}

          true ->
            resolve_user_and_issue_token(uid, attrs, email)
        end
    end
  end

  defp normalize_firebase_email(nil), do: nil

  defp normalize_firebase_email(email) when is_binary(email) do
    case String.trim(email) do
      "" -> nil
      e -> e
    end
  end

  defp normalize_firebase_email(_), do: nil

  defp firebase_email_verified?(attrs, email) do
    v = Map.get(attrs, "email_verified") || Map.get(attrs, "emailVerified")

    cond do
      is_boolean(v) ->
        v

      v in ["true", "1", 1] ->
        true

      v in ["false", "0", 0] ->
        false

      email in [nil, ""] ->
        true

      true ->
        # Flag omitted (common when wrapping Firebase `User`); treat as verified if email present
        true
    end
  end

  defp resolve_user_and_issue_token(uid, attrs, email) do
    user =
      case get_user_by_firebase_auth_id(uid) do
        %User{} = u ->
          {:ok, u}

        nil ->
          case email do
            nil ->
              {:needs_link, nil}

            e ->
              case get_user_by_email(e) do
                %User{} = u -> {:needs_link, u}
                nil -> {:missing, nil}
              end
          end
      end

    case user do
      {:ok, u} ->
        u = maybe_update_profile_from_firebase(u, attrs)
        issue_member_session(u)

      {:needs_link, %User{} = u} ->
        case User.changeset(u, %{firebase_auth_id: uid}) |> Repo.update() do
          {:ok, u} ->
            u = u |> Repo.preload([:organization])
            u = maybe_update_profile_from_firebase(u, attrs)
            issue_member_session(u)

          {:error, changeset} ->
            {:error, {:could_not_link_firebase, changeset}}
        end

      {:needs_link, nil} ->
        {:error, :firebase_user_needs_email}

      {:missing, nil} ->
        {:error, :no_account_for_firebase}
    end
  end

  defp maybe_update_profile_from_firebase(%User{} = u, attrs) do
    name = attrs["name"] || attrs["displayName"]
    updates = %{}

    updates =
      if is_binary(name) and String.trim(name) != "" and (is_nil(u.fullname) or u.fullname == "") do
        Map.put(updates, :fullname, String.trim(name))
      else
        updates
      end

    em = normalize_firebase_email(attrs["email"] || Map.get(attrs, "email"))

    updates =
      if is_binary(em) and em != "" and (is_nil(u.email) or u.email == "") do
        Map.put(updates, :email, em)
      else
        updates
      end

    if map_size(updates) > 0 do
      case User.changeset(u, updates) |> Repo.update() do
        {:ok, u} -> u |> Repo.preload([:organization])
        {:error, _} -> u
      end
    else
      u
    end
  end

  defp issue_member_session(%User{} = user) do
    user = Repo.preload(user, [:merchant, :rank, :stockist_users])
    token = member_token(user.id)
    create_session_user(%{"cookie" => token, "user_id" => user.id})

    u =
      user
      |> BluePotion.sanitize_struct()
      |> Map.put(:token, token)

    {:ok, %{user: u, token: token}}
  end

  def get_staff_by_username(username) when is_binary(username) do
    Repo.one(
      from(s in Staff,
        where: s.username == ^username,
        preload: [:organization, role: :app_routes]
      )
    )
  end

  def check_staff_password(params) do
    users =
      Repo.all(
        from(u in Staff,
          where: u.username == ^params["username"],
          preload: [:organization, role: :app_routes]
        )
      )
      |> IO.inspect()

    if users != [] do
      user = List.first(users)

      crypted_password =
        :crypto.hash(:sha512, params["password"] |> IO.inspect())
        |> Base.encode16()
        |> String.downcase()
        |> IO.inspect()

      {crypted_password == user.crypted_password, user} |> IO.inspect()
    else
      {false, nil}
    end
  end

  def get_admin_staff() do
    check = Repo.all(from(r in Role, where: r.name == "Owner")) |> IO.inspect()

    if check == [] do
      {:ok, role} = create_role(%{name: "Owner", desc: "own and manage the company "})
      role
    else
      List.first(check)
    end
  end

  def menu_list() do
    %{
      "0" => %{
        "children" => %{
          "0" => %{
            "icon" => "camera-foto-solid",
            "path" => "/admin/staff",
            "title" => "Staff"
          },
          "1" => %{
            "icon" => "camera-foto-solid",
            "path" => "/admin/role",
            "title" => "Role"
          },
          "2" => %{
            "icon" => "camera-foto-solid",
            "path" => "/admin/app_route",
            "title" => "Route"
          },
          "3" => %{
            "icon" => "camera-foto-solid",
            "path" => "/merchants/categories",
            "title" => "Merchant Business Categories"
          }
        },
        "icon" => "",
        "path" => "#",
        "title" => "Admin"
      },
      "1" => %{
        "children" => %{
          "0" => %{
            "icon" => "camera-foto-solid",
            "path" => "/geo/countries",
            "title" => "Country"
          },
          "1" => %{
            "icon" => "camera-foto-solid",
            "path" => "/geo/states",
            "title" => "States"
          },
          "2" => %{
            "icon" => "camera-foto-solid",
            "path" => "/geo/pick_up_points",
            "title" => "Pick Up Points"
          }
        },
        "icon" => "",
        "path" => "#",
        "title" => "Geo"
      },
      "10" => %{
        "children" => %{
          "0" => %{"icon" => "book-solid", "path" => "/users", "title" => "Users"},
          "1" => %{
            "icon" => "book-solid",
            "path" => "/users/placements",
            "title" => "Placements"
          }
        },
        "icon" => "",
        "path" => "#",
        "title" => "Users"
      },
      "11" => %{"icon" => "book-solid", "path" => "/ranks", "title" => "Rank"},
      "12" => %{
        "children" => %{
          "0" => %{
            "icon" => "camera-foto-solid",
            "path" => "/ewallets/withdrawal_batches",
            "title" => "Withdrawal"
          },
          "1" => %{
            "icon" => "camera-foto-solid",
            "path" => "/ewallets/merchant_withdrawals",
            "title" => "Merchant Withdrawal"
          },
          "2" => %{
            "icon" => "book-solid",
            "path" => "/ewallets",
            "title" => "Ewallets"
          },
          "3" => %{
            "icon" => "camera-foto-solid",
            "path" => "/ewallets/transfers",
            "title" => "Transfers"
          },
          "4" => %{
            "icon" => "camera-foto-solid",
            "path" => "/ewallets/register_points",
            "title" => "Register Points"
          }
        },
        "icon" => "",
        "path" => "#",
        "title" => "Ewallets"
      },
      "2" => %{
        "icon" => "book-solid",
        "path" => "/announcements",
        "title" => "Announcements"
      },
      "3" => %{"icon" => "book-solid", "path" => "/slides", "title" => "Slides"},
      "4" => %{
        "children" => %{
          "0" => %{
            "icon" => "camera-foto-solid",
            "path" => "/rewards/summary",
            "title" => "Commission Summary"
          },
          "1" => %{
            "icon" => "camera-foto-solid",
            "path" => "/rewards/details",
            "title" => "Commission Details"
          },
          "2" => %{
            "icon" => "camera-foto-solid",
            "path" => "/rewards",
            "title" => "All Commission"
          },
          "3" => %{
            "icon" => "camera-foto-solid",
            "path" => "/rewards/royalty_users",
            "title" => "Royalty Users"
          }
        },
        "icon" => "",
        "path" => "#",
        "title" => "Commission"
      },
      "5" => %{
        "children" => %{
          "0" => %{
            "icon" => "book-solid",
            "path" => "/referral_gs_summary",
            "title" => "Referral GS Summary"
          },
          "1" => %{
            "icon" => "book-solid",
            "path" => "/referral_gs_details",
            "title" => "Referral GS Details"
          },
          "2" => %{
            "icon" => "book-solid",
            "path" => "/gs_summary",
            "title" => "Placement GS Summary"
          },
          "3" => %{
            "icon" => "book-solid",
            "path" => "/group_sales_details",
            "title" => "Placement GS Details"
          }
        },
        "icon" => "",
        "path" => "#",
        "title" => "GroupSales"
      },
      "6" => %{
        "icon" => "book-solid",
        "path" => "/deliveries",
        "title" => "Deliveries"
      },
      "7" => %{
        "icon" => "book-solid",
        "path" => "/merchants",
        "title" => "Merchants"
      },
      "8" => %{"icon" => "book-solid", "path" => "/sales", "title" => "Sales"},
      "9" => %{
        "children" => %{
          "0" => %{
            "icon" => "book-solid",
            "path" => "/products",
            "title" => "Product"
          },
          "1" => %{"icon" => "book-solid", "path" => "/stocks", "title" => "Stocks"},
          "2" => %{
            "icon" => "book-solid",
            "path" => "/stock_adjustments",
            "title" => "Stock Adjustments"
          },
          "3" => %{
            "icon" => "book-solid",
            "path" => "/stocks/summaries",
            "title" => "Stocks Summaries"
          }
        },
        "icon" => "",
        "path" => "#",
        "title" => "Stocks"
      }
    }
  end

  def update_admin_menus(list) do
    IO.inspect(list)
    # how to retain existing role app route?

    rars = Repo.all(from(r in Role, preload: [:app_routes]))

    Multi.new()
    |> Multi.run(:update, fn _repo, %{} ->
      Repo.delete_all(AppRoute)
      Repo.delete_all(RoleAppRoute)

      for role <- rars do
        list = list |> Map.values()

        for menu <- list do
          {:ok, route} =
            create_app_route(%{
              "name" => menu |> Map.get("title"),
              "route" => menu |> Map.get("path"),
              "icon" => menu |> Map.get("icon")
            })

          admin_role = get_admin_staff()

          cg =
            RoleAppRoute.changeset(%RoleAppRoute{}, %{
              role_id: role.id,
              app_route_id: route.id
            })

          if role.name == admin_role.name do
            cg
            |> Repo.insert()
          else
            if role.app_routes
               |> Enum.filter(&(&1.route == route.route))
               |> Enum.filter(&(&1.name == route.name)) != [] do
              cg
              |> Repo.insert()
            end
          end

          children = Map.get(menu, "children", %{}) |> Map.values()

          for child <- children do
            {:ok, croute} =
              create_app_route(%{
                "name" => child |> Map.get("title"),
                "route" => child |> Map.get("path"),
                "icon" => child |> Map.get("icon")
              })

            ccg =
              RoleAppRoute.changeset(%RoleAppRoute{}, %{
                role_id: role.id,
                app_route_id: croute.id
              })

            if role.name == admin_role.name do
              ccg
              |> Repo.insert()
            else
              if role.app_routes
                 |> Enum.filter(&(&1.route == croute.route))
                 |> Enum.filter(&(&1.name == croute.name)) != [] do
                ccg
                |> Repo.insert()
              end
            end
          end
        end
      end

      {:ok, nil}
    end)
    |> Repo.transaction()
  end

  def update_svt_menus() do
    menu_list() |> update_admin_menus()
  end

  def populate_menus(menus) do
    rars = Repo.all(from(r in Role, preload: [:app_routes]))

    Multi.new()
    |> Multi.run(:update, fn _repo, %{} ->
      Repo.delete_all(AppRoute)
      Repo.delete_all(RoleAppRoute)

      for role <- rars do
        for menu <- menus do
          {:ok, route} =
            create_app_route(%{
              "name" => menu |> Map.get("title"),
              "route" => menu |> Map.get("path"),
              "icon" => menu |> Map.get("icon")
            })

          admin_role = get_admin_staff()

          cg =
            RoleAppRoute.changeset(%RoleAppRoute{}, %{
              role_id: role.id,
              app_route_id: route.id
            })

          if role.name == admin_role.name do
            cg
            |> Repo.insert()
          else
            if role.app_routes
               |> Enum.filter(&(&1.route == route.route))
               |> Enum.filter(&(&1.name == route.name)) != [] do
              cg
              |> Repo.insert()
            end
          end

          children = Map.get(menu, "children", %{})

          for child <- children do
            {:ok, croute} =
              create_app_route(%{
                "name" => child |> Map.get("title"),
                "route" => child |> Map.get("path"),
                "icon" => child |> Map.get("icon")
              })

            ccg =
              RoleAppRoute.changeset(%RoleAppRoute{}, %{
                role_id: role.id,
                app_route_id: croute.id
              })

            if role.name == admin_role.name do
              ccg
              |> Repo.insert()
            else
              if role.app_routes
                 |> Enum.filter(&(&1.route == croute.route))
                 |> Enum.filter(&(&1.name == croute.name)) != [] do
                ccg
                |> Repo.insert()
              end
            end
          end
        end
      end

      {:ok, nil}
    end)
    |> Repo.transaction()
  end

  alias BlogEngine.Settings.Blog

  def list_blogs(opts \\ nil, limit \\ 10) do
    category_name = opts |> Map.get("category", nil)

    is_page = opts |> Map.get("is_page", false)

    limit = opts |> Map.get("limit", limit)

    only_child = opts |> Map.get("only_child", false)

    q =
      if category_name != nil do
        from(b in Blog,
          left_join: c in BlogEngine.Settings.Category,
          on: c.id == b.category_id,
          left_join: cc in BlogEngine.Settings.Category,
          on: cc.id == c.parent_id,
          where: cc.name == ^category_name,
          or_where: c.name == ^category_name,
          preload: [:category, :stored_medias],
          limit: ^limit,
          order_by: [desc: b.inserted_at]
        )
      else
        from(b in Blog,
          preload: [:category, :stored_medias],
          limit: ^limit,
          order_by: [desc: b.inserted_at]
        )
      end

    q =
      if only_child do
        q
        |> where([b, c, cc], c.name != ^category_name)
      else
        q
      end

    Repo.all(q)
  end

  def list_blog_next_prev(id, category_id) do
    # b = Repo.all(from b in Blog, where: b.id == ^id) |> List.first()

    list =
      Repo.all(
        from(b in Blog,
          where: b.category_id == ^category_id,
          order_by: [asc: b.inserted_at],
          select: %{id: b.id, inserted_at: b.inserted_at, title: b.title}
        )
      )
      |> IO.inspect()

    index = Enum.find_index(list, &(&1.id == id)) |> IO.inspect()

    prev =
      if index == 0 do
        nil
      else
        Enum.at(list, index - 1)
      end

    next = Enum.at(list, index + 1)

    %{next: next, prev: prev}
  end

  def get_blog!(id) do
    Repo.get!(Blog, id) |> Repo.preload([:category, :stored_medias])
  end

  def create_blog(params \\ %{}) do
    Blog.changeset(%Blog{}, params) |> Repo.insert() |> IO.inspect()
  end

  def update_blog(model, params) do
    Blog.changeset(model, params) |> Repo.update() |> IO.inspect()
  end

  def delete_blog(%Blog{} = model) do
    Repo.delete(model)
  end

  alias BlogEngine.Settings.Category

  def list_categories() do
    Repo.all(Category)
  end

  def get_category!(id) do
    Repo.get!(Category, id)
  end

  def create_category(params \\ %{}) do
    Category.changeset(%Category{}, params) |> Repo.insert() |> IO.inspect()
  end

  def update_category(model, params) do
    Category.changeset(model, params) |> Repo.update() |> IO.inspect()
  end

  def delete_category(%Category{} = model) do
    Repo.delete(model)
  end

  alias BlogEngine.Settings.StoredMedia

  def list_stored_medias() do
    Repo.all(StoredMedia)
  end

  def get_stored_media!(id) do
    Repo.get!(StoredMedia, id)
  end

  def create_stored_media(params \\ %{}) do
    StoredMedia.changeset(%StoredMedia{}, params) |> Repo.insert() |> IO.inspect()
  end

  def update_stored_media(model, params) do
    StoredMedia.changeset(model, params) |> Repo.update() |> IO.inspect()
  end

  def delete_stored_media(%StoredMedia{} = model) do
    Repo.delete(model)
  end

  def get_outstanding_works(device_name \\ "00000000-0000-0000-d83a-dda0064d") do
    q = from(dl in DeviceLog, left_join: d in Device, on: d.id == dl.device_id)

    job_uuids =
      DeviceLog
      |> join(:left, [dl], d in Device, on: dl.device_id == d.id)
      |> where([dl, d], d.name == ^device_name)
      |> group_by([dl, d], [dl.uuid])
      |> select([dl, d], %{count: count(dl.uuid), uuid: dl.uuid})
      |> Repo.all()
      |> Enum.filter(&(&1.count < 2))
      |> Enum.map(& &1.uuid)
      |> IO.inspect()

    jobs =
      DeviceLog
      |> where([dl], dl.uuid in ^job_uuids)
      |> where([dl], is_nil(dl.job_content))
      |> Repo.delete_all()

    jobs =
      DeviceLog
      |> join(:left, [dl], d in Device, on: dl.device_id == d.id)
      |> where([dl, d], d.name == ^device_name)
      |> where([dl, d], dl.uuid in ^job_uuids)
      |> order_by([dl, d], desc: dl.id)
      |> Repo.all()
      |> IO.inspect()

    for job <- jobs do
      uuid = job |> Map.get(:uuid)

      dl =
        DeviceLog
        |> where([dl], dl.uuid == ^uuid)
        |> Repo.all()
        |> IO.inspect()
        |> List.first()

      if dl != nil do
        BlogEngineWeb.Endpoint.broadcast(
          "user:#{device_name}",
          "start_pwm",
          Jason.decode!(dl.job_content)
        )
      end
    end
  end

  @doc """
  BlogEngine.Settings.get_call_counts_with_empty_minutes(7, )
  """
  def get_call_counts_with_empty_minutes(device_id, limit \\ "") do
    {y, m, d} = Date.utc_today() |> Date.to_erl()

    {:ok, start_datetime} = NaiveDateTime.from_erl({{y, m, d}, {0, 0, 0}}) |> IO.inspect()
    end_datetime = start_datetime |> Timex.shift(days: 1)

    query = """
    WITH RECURSIVE minutes_series AS (
      SELECT
        date_trunc('minute', min(inserted_at)) AS minute
      FROM
        device_time_logs
      WHERE
        device_id = $1 AND inserted_at BETWEEN $2 AND $3
      UNION ALL
      SELECT
        minute + interval '1 minute'
      FROM
        minutes_series
      WHERE
        minute + interval '1 minute' <= (
          SELECT
            max(inserted_at)
          FROM
            device_time_logs
          WHERE
            device_id = $1 AND inserted_at BETWEEN $2 AND $3
        )
    )
    SELECT
      m.minute,
      COUNT(d.id) AS call_count
    FROM
      minutes_series m
      LEFT JOIN device_time_logs d ON date_trunc('minute', d.inserted_at) = m.minute AND d.device_id = $1 AND d.inserted_at BETWEEN $2 AND $3
    GROUP BY
      m.minute
    ORDER BY
      m.minute DESC #{limit};
    """

    Repo.query!(query, [device_id, start_datetime, end_datetime])
    |> Map.get(:rows)
  end

  @doc """
  Grouped WiFi "online" logs for a device, returned in a DataTables-style shape.

  This uses `device_time_logs` (each row = "online ping") and groups into 1-minute buckets.

  Expected params:
  - "id" (device id)
  - "length" (page size)
  - "start" (offset)
  - "draw" (datatable draw id)
  """
  def device_wifi_logs_grouped_datatable(params) do
    parse_int = fn value, default ->
      case value do
        nil ->
          default

        v when is_integer(v) ->
          v

        v when is_binary(v) ->
          case Integer.parse(v) do
            {i, _} -> i
            _ -> default
          end

        _ ->
          default
      end
    end

    device_id =
      params
      |> Map.get("id")
      |> parse_int.(0)

    limit = parse_int.(Map.get(params, "length"), 20)
    offset = parse_int.(Map.get(params, "start"), 0)
    draw = parse_int.(Map.get(params, "draw"), 1)

    date =
      case Map.get(params, "date") do
        nil ->
          Date.utc_today()

        date_str when is_binary(date_str) ->
          case Date.from_iso8601(date_str) do
            {:ok, d} -> d
            _ -> Date.utc_today()
          end

        _ ->
          Date.utc_today()
      end

    {y, m, d} = date |> Date.to_erl()
    {:ok, start_datetime} = NaiveDateTime.from_erl({{y, m, d}, {0, 0, 0}})
    end_datetime = start_datetime |> Timex.shift(days: 1)

    query = """
    WITH hours_series AS (
      SELECT generate_series($2::timestamp, ($3::timestamp - interval '1 hour'), interval '1 hour') AS hour
    ),
    agg AS (
      SELECT
        date_trunc('hour', inserted_at) AS hour,
        COUNT(*) AS call_count
      FROM device_time_logs
      WHERE device_id = $1
        AND inserted_at >= $2
        AND inserted_at < $3
      GROUP BY 1
    ),
    counts AS (
      SELECT
        h.hour,
        COALESCE(a.call_count, 0) AS call_count
      FROM
        hours_series h
        LEFT JOIN agg a ON a.hour = h.hour
    )
    SELECT
      hour,
      call_count,
      COUNT(*) OVER() AS total_count
    FROM
      counts
    ORDER BY
      hour DESC
    LIMIT $4 OFFSET $5;
    """

    res = Repo.query!(query, [device_id, start_datetime, end_datetime, limit, offset])

    {data, total} =
      case res.rows do
        [] ->
          {[], 0}

        rows ->
          total = rows |> List.first() |> Enum.at(2) || 0

          data =
            rows
            |> Enum.map(fn [hour, call_count, _total_count] ->
              %{
                hour: hour |> NaiveDateTime.to_iso8601(),
                call_count: call_count
              }
            end)

          {data, total}
      end

    %{
      data: data,
      recordsTotal: total,
      recordsFiltered: total,
      draw: draw
    }
  end

  @doc """
  Weekly grouped WiFi logs (device_time_logs) within a selected month.

  Params:
  - "id": device id
  - "month": "YYYY-MM" (defaults to current month)
  - "length", "start", "draw": DataTables pagination params

  Returns DataTables-style map: %{data, recordsTotal, recordsFiltered, draw}
  where each row is %{week_start, week_end, call_count}.
  """
  def device_wifi_logs_weekly_in_month_datatable(params) do
    parse_int = fn value, default ->
      case value do
        nil ->
          default

        v when is_integer(v) ->
          v

        v when is_binary(v) ->
          case Integer.parse(v) do
            {i, _} -> i
            _ -> default
          end

        _ ->
          default
      end
    end

    device_id =
      params
      |> Map.get("id")
      |> parse_int.(0)

    limit = parse_int.(Map.get(params, "length"), 10)
    offset = parse_int.(Map.get(params, "start"), 0)
    draw = parse_int.(Map.get(params, "draw"), 1)

    month_str =
      case Map.get(params, "month") do
        m when is_binary(m) and byte_size(m) >= 7 -> String.slice(m, 0, 7)
        _ -> Date.utc_today() |> Date.to_iso8601() |> String.slice(0, 7)
      end

    month_start =
      case Date.from_iso8601(month_str <> "-01") do
        {:ok, d} -> d
        _ -> Date.utc_today() |> Date.beginning_of_month()
      end

    # first day of next month
    month_end = month_start |> Date.add(Date.days_in_month(month_start))

    {:ok, start_datetime} = NaiveDateTime.from_erl({month_start |> Date.to_erl(), {0, 0, 0}})
    {:ok, end_datetime} = NaiveDateTime.from_erl({month_end |> Date.to_erl(), {0, 0, 0}})

    query = """
    WITH weeks AS (
      SELECT
        gs AS week_start,
        LEAST(gs + interval '7 day', $3::timestamp) AS week_end
      FROM generate_series($2::timestamp, ($3::timestamp - interval '1 day'), interval '7 day') AS gs
    ),
    counts AS (
      SELECT
        w.week_start,
        w.week_end,
        COUNT(d.id) AS call_count
      FROM
        weeks w
        LEFT JOIN device_time_logs d
          ON d.device_id = $1
          AND d.inserted_at >= w.week_start
          AND d.inserted_at < w.week_end
      GROUP BY
        w.week_start, w.week_end
    )
    SELECT
      week_start,
      week_end,
      call_count,
      COUNT(*) OVER() AS total_count
    FROM counts
    ORDER BY week_start DESC
    LIMIT $4 OFFSET $5;
    """

    res = Repo.query!(query, [device_id, start_datetime, end_datetime, limit, offset])

    {data, total} =
      case res.rows do
        [] ->
          {[], 0}

        rows ->
          total = rows |> List.first() |> Enum.at(3) || 0

          data =
            rows
            |> Enum.map(fn [week_start, week_end, call_count, _total_count] ->
              %{
                week_start: week_start |> NaiveDateTime.to_iso8601(),
                week_end: week_end |> NaiveDateTime.to_iso8601(),
                call_count: call_count
              }
            end)

          {data, total}
      end

    %{
      data: data,
      recordsTotal: total,
      recordsFiltered: total,
      draw: draw
    }
  end

  def delete_all_pending_sales() do
    res = Repo.all(from(s in Sale, where: s.status == ^:pending_payment, preload: [:sales_items]))

    ids = res |> Enum.map(& &1.sales_items) |> List.flatten() |> Enum.map(& &1.id)

    Repo.delete_all(from(si in SalesItem, where: si.id in ^ids))

    res = Repo.delete_all(from(s in Sale, where: s.status == ^:pending_payment))
  end

  def check_last_mins(device_id, skip_check \\ false) do
    if skip_check do
      0
    else
      res = BlogEngine.Settings.get_call_counts_with_empty_minutes(device_id, "LIMIT 30")

      case res |> hd do
        [nil, count] ->
          999

        [last_time, count] ->
          IO.inspect(count)
          DateTime.utc_now() |> DateTime.diff(last_time |> DateTime.from_naive!("GMT+0"))

        _ ->
          999
      end
    end
  end

  def copy_items_from_outlet(from_outlet_id, to_outlet_id) do
    items =
      Repo.all(from(i in Item, where: i.outlet_id == ^from_outlet_id))
      |> Enum.map(
        &(&1
          |> BluePotion.sanitize_struct()
          |> Map.delete(:id)
          |> Map.put(:outlet_id, to_outlet_id)
          |> create_item())
      )
  end

  alias BlogEngine.Settings.Product

  def list_products() do
    Repo.all(from(p in Product, preload: [:brand, :category]))
  end

  def get_product!(id) do
    Repo.get!(Product, id)
  end

  def create_product(params \\ %{}) do
    Product.changeset(%Product{}, params) |> Repo.insert() |> IO.inspect()
  end

  def update_product(model, params) do
    Product.changeset(model, params) |> Repo.update() |> IO.inspect()
  end

  def delete_product(%Product{} = model) do
    Repo.delete(model)
  end

  alias BlogEngine.Settings.Brand

  def list_brands() do
    Repo.all(Brand)
  end

  def get_brand!(id) do
    Repo.get!(Brand, id)
  end

  def create_brand(params \\ %{}) do
    Brand.changeset(%Brand{}, params) |> Repo.insert() |> IO.inspect()
  end

  def update_brand(model, params) do
    Brand.changeset(model, params) |> Repo.update() |> IO.inspect()
  end

  def delete_brand(%Brand{} = model) do
    Repo.delete(model)
  end

  alias BlogEngine.Settings.Page

  def list_pages() do
    Repo.all(from(p in Page, order_by: [desc: p.sorting_index]))
  end

  def get_page!(id) do
    Repo.get!(Page, id)
  end

  def create_page(params \\ %{}) do
    Page.changeset(%Page{}, params) |> Repo.insert() |> IO.inspect()
  end

  def update_page(model, params) do
    res = Page.changeset(model, params) |> Repo.update() |> IO.inspect()

    case HTTPoison.get(
           "#{Application.get_env(:blog_engine, :mbos_api)}/blog_updates",
           [{"Content-Type", "application/json"}]
         ) do
      {:ok,
       %HTTPoison.Response{
         body: body
       } = _res} ->
        body |> IO.puts()

      _ ->
        nil
    end

    res
  end

  def delete_page(%Page{} = model) do
    Repo.delete(model)
  end

  alias BlogEngine.Settings.Section

  def list_sections() do
    Repo.all(Section)
  end

  def get_section!(id) do
    Repo.get!(Section, id)
  end

  def get_section_by_name(name) do
    Repo.get_by(Section, name: name)
  end

  def create_section(params \\ %{}) do
    Section.changeset(%Section{}, params) |> Repo.insert() |> IO.inspect()
  end

  def update_section(model, params) do
    Section.changeset(model, params) |> Repo.update() |> IO.inspect()
  end

  def delete_section(%Section{} = model) do
    Repo.delete(model)
  end

  alias BlogEngine.Settings.MessagingDevice

  def list_messaging_devices() do
    Repo.all(MessagingDevice)
  end

  def get_messaging_device!(id) do
    Repo.get!(MessagingDevice, id)
  end

  def create_messaging_device(params \\ %{}) do
    check = Repo.all(from(md in MessagingDevice, where: md.uuid == ^params["uuid"]))

    if check == [] do
      MessagingDevice.changeset(%MessagingDevice{}, params) |> Repo.insert() |> IO.inspect()
    else
      {:ok, List.first(check)}
    end
  end

  @doc """
  token = "cxA382NUQHilGS5bG2_MLC:APA91bG6Pjr7WIQhQoZxydY-HdAMshjlwJlw2CRomvoeaY5PH6k4jfGKKIyFfoCe6Sk5r01fLpdZL5hHf8ZtZEXuhb2zhpoK_oxFvCDEPkJutGuobE_v4kM"
  token2 = "e93U-8-eR5qKAwJxeAmSnv:APA91bFNUaplqITRXqUgS0B2nQbGREqivZ43zo2W0X8arghHRZfwhDntRpwUkMxTn-0s6PRIc5VnSwPZXvt8ayc4jfPQKZht9XHhB0BXAAzOAMezP_i_lX8"
  token3 = "cCUrkp9MTKqAtxZDHtn98k:APA91bExUa1DgRF8KkpwDeH3I6pWIwCkA5wlH_QXs1HUlnJoj0cQ5rWwuI90h1PPiz1aPPauXbAw1GNyfl_2z8Yv71QRvLxoOO74wbXktSGIBqyHk2R_ibs"
  token4 = "eJRAfsja5FVidAk_j-OJLI:APA91bEQHMIvuFCX_7qpXJKDoNbA_wOK9_WT1mbQesdg3cF-91cn4pyk18xQc1fZWm5ZSVxRMGjdvZW7SSIIImRycJkM8vyW4KdqzOpiVcrb3mp1Hey1a7I"
  tokens = ["f3pQYoBpTKqPjAkDmiXCgD:APA91bG6JxQ6tgD8IzQnd2ADJB79HQoNuXBvzuH-pr9OK7aTE2Y4HSqrVhbF-ho6Qo44SRCcWIwB-aHcK3PTWejGVkheQVvKG7w67lHayYOPYWmTYDR-ZRE"]


  Enum.map(tokens, &   BlogEngine.Settings.fcm_publish(0, "Salam Dari DJTECH", "Anda boleh periksa keadaan mesin dari sini", &1))
  """
  def fcm_publish(
        id,
        title,
        body,
        device_token \\ "cXh-Hxbk88EuxnkpTuDySj:APA91bGZombjdutaWzQomruMWYclBo1JGnhg_V6fGAuZ5_RIrFzrWXDx_qnTC2_q66RJJUuFhV-I3V2RtQD7ffStOq8xuT19fejsNNj0kR-isS5qcE_5JKQ",
        opts \\ []
      ) do
    default_profile =
      Application.get_env(:blog_engine, :fcm, [])
      |> Keyword.get(:default_profile, "main")

    profile = Keyword.get(opts, :profile, default_profile)
    BlogEngine.Fcm.publish(profile, id, title, body, device_token)
  end

  @doc """
  Notifies a member (`User`) via FCM after a staff refund credit, when `fcm_token` is set.
  Dispatches `fcm_publish/4` in a background task so the webhook responds quickly.

  user =  BlogEngine.Settings.get_user!(3)
  BlogEngine.Settings.fcm_notify_member_refund_credited(user, 1, 3)
  """
  def fcm_notify_member_refund_credited(%User{} = user, amount, transaction_id)
      when is_number(amount) do
    token =
      case user.fcm_token do
        t when is_binary(t) -> String.trim(t)
        _ -> ""
      end

    if token != "" do
      amt_label =
        case amount do
          n when is_integer(n) -> Integer.to_string(n)
          n when is_float(n) -> :erlang.float_to_binary(n, [:compact, decimals: 2])
        end

      title = "Refund processed"

      body = "Your refund has been processed and #{amt_label} token(s) credited to your account."

      tid =
        case transaction_id do
          id when is_integer(id) -> id
          _ -> 0
        end

      member_profile =
        Application.get_env(:blog_engine, :fcm, [])
        |> Keyword.get(:member_profile, "hub")

      member_profile = get_fcm_profile_by_org_id(user.organization_id)

      # if get hub, should fail

      Task.start(fn -> fcm_publish(tid, title, body, token, profile: member_profile) end)
    end

    :ok
  end

  @doc """
  FCM registration tokens for staff in an organization (from `messaging_devices.uuid`).
  """
  def list_staff_fcm_tokens_for_organization(organization_id) when is_integer(organization_id) do
    Repo.all(
      from(md in MessagingDevice,
        join: s in Staff,
        on: s.id == md.staff_id,
        where: s.organization_id == ^organization_id,
        where: not is_nil(md.uuid),
        select: md.uuid
      )
    )
    |> Enum.filter(fn t -> is_binary(t) and String.trim(t) != "" end)
    |> Enum.uniq()
  end

  @doc """
  Resolves the FCM profile key for an organization based on its normalized/slugified name.
  """
  def get_fcm_profile_by_org_id(org_id) when is_integer(org_id) do
    case Repo.get(Organization, org_id) do
      %Organization{name: name} when is_binary(name) ->
        name
        |> String.downcase()
        |> String.replace(~r/[^a-z0-9_-]/, "")

      _ ->
        "main"
    end
  end

  def get_fcm_profile_by_org_id(_), do: "main"

  @doc """
  Notifies operators (staff with FCM device tokens registered for the org) when a member
  joins the organization support channel.
  """
  def fcm_notify_org_operators_member_joined(organization_id, member_label, member_id \\ 0)
      when is_integer(organization_id) and is_binary(member_label) do
    label = String.trim(member_label)

    title = "Member joined support"

    body =
      if label != "" do
        "#{label} joined the support room."
      else
        "A member joined the support room."
      end

    mid =
      case member_id do
        id when is_integer(id) -> id
        _ -> 0
      end

    profile = get_fcm_profile_by_org_id(organization_id)

    for token <- list_staff_fcm_tokens_for_organization(organization_id) do
      Task.start(fn -> fcm_publish(mid, title, body, token, profile: profile) end)
    end

    :ok
  end

  @doc """
  Notifies operators (staff with FCM device tokens registered for the org) when a member
  makes a top-up payment.
  """
  def fcm_notify_org_operators_topup(organization_id, user_id, amount)
      when is_integer(organization_id) and is_integer(user_id) do
    user = get_user!(user_id)
    user_lbl = user_label(user)

    title = "Customer Top-up"
    body = "#{user_lbl} has successfully topped up RM #{amount}."

    profile = get_fcm_profile_by_org_id(organization_id) |> IO.inspect(label: "profile")

    for token <- list_staff_fcm_tokens_for_organization(organization_id) do
      Task.start(fn -> fcm_publish(0, title, body, token, profile: profile) end)
    end

    :ok
  end

  defp user_label(%User{fullname: n, username: u}) do
    cond do
      is_binary(n) and String.trim(n) != "" -> n
      is_binary(u) and String.trim(u) != "" -> u
      true -> "Member"
    end
  end

  def update_messaging_device(model, params) do
    MessagingDevice.changeset(model, params) |> Repo.update() |> IO.inspect()
  end

  def delete_messaging_device(%MessagingDevice{} = model) do
    Repo.delete(model)
  end

  @doc """
  Operator app: devices for an organization with last ping, online flag (recent device_time_logs),
  and today's sales totals split by cash vs QR-style payments (`sales_type` / `payment_channel`).
  """
  def operator_devices_summary(params) when is_map(params) do
    org_id =
      case Map.get(params, "organization_id") do
        nil ->
          nil

        v when is_binary(v) ->
          case Integer.parse(v) do
            {i, _} -> i
            :error -> nil
          end

        v when is_integer(v) ->
          v
      end

    outlet_id =
      case Map.get(params, "outlet_id") do
        nil ->
          nil

        "" ->
          nil

        v when is_binary(v) ->
          case Integer.parse(v) do
            {i, _} -> i
            :error -> nil
          end

        v when is_integer(v) ->
          v
      end

    if org_id == nil do
      []
    else
      outlet_filter =
        if outlet_id do
          " AND d.outlet_id = $2 "
        else
          ""
        end

      bind = if outlet_id, do: [org_id, outlet_id], else: [org_id]

      query = """
      SELECT
        d.id,
        d.name,
        d.label,
        d.short_name,
        o.name AS outlet_name,
        (
          SELECT MAX(dtl.inserted_at)
          FROM device_time_logs dtl
          WHERE dtl.device_id = d.id
        ) AS last_seen_at,
        COALESCE(ts.today_total, 0) AS today_sales_total,
        COALESCE(ts.today_cash, 0) AS today_sales_cash,
        COALESCE(ts.today_qr, 0) AS today_sales_qr
      FROM devices d
      LEFT JOIN outlets o ON o.id = d.outlet_id
      LEFT JOIN LATERAL (
        SELECT
          SUM(s.amount) AS today_total,
          SUM(s.amount) FILTER (WHERE COALESCE(s.sales_type, '') = 'cash') AS today_cash,
          SUM(s.amount) FILTER (
            WHERE COALESCE(s.sales_type, '') = 'offline'
              OR (s.payment_channel IS NOT NULL AND (
                s.payment_channel ILIKE '%qr%'
                OR s.payment_channel ILIKE '%duitnow%'
                OR s.payment_channel = 'duitnowsqr'
              ))
          ) AS today_qr
        FROM sales s
        WHERE s.device_id = d.id
          AND s.status = 'complete'
          AND DATE((s.inserted_at AT TIME ZONE 'UTC') AT TIME ZONE 'Asia/Kuala_Lumpur')
            = DATE(timezone('Asia/Kuala_Lumpur', now()))
      ) ts ON true
      WHERE d.organization_id = $1
      #{outlet_filter}
      ORDER BY o.name NULLS LAST, d.label NULLS LAST, d.short_name NULLS LAST, d.name
      """

      {:ok, %Postgrex.Result{columns: columns, rows: rows}} = Repo.query(query, bind)

      Enum.map(rows, fn row ->
        map = Enum.zip(columns |> Enum.map(&String.to_atom/1), row) |> Enum.into(%{})

        last_seen = Map.get(map, :last_seen_at)

        is_online =
          case last_seen do
            %NaiveDateTime{} = ndt ->
              dt = DateTime.from_naive!(NaiveDateTime.truncate(ndt, :second), "Etc/UTC")

              DateTime.diff(DateTime.utc_now(), dt, :second) >= 0 &&
                DateTime.diff(DateTime.utc_now(), dt, :second) <= 180

            %DateTime{} = dt ->
              DateTime.diff(DateTime.utc_now(), dt, :second) >= 0 &&
                DateTime.diff(DateTime.utc_now(), dt, :second) <= 180

            _ ->
              false
          end

        map
        |> Map.put(:is_online, is_online)
        |> Map.update!(:today_sales_total, &decimal_to_float/1)
        |> Map.update!(:today_sales_cash, &decimal_to_float/1)
        |> Map.update!(:today_sales_qr, &decimal_to_float/1)
      end)
    end
  end

  defp decimal_to_float(%Decimal{} = d), do: Decimal.to_float(d)
  defp decimal_to_float(n) when is_number(n), do: n * 1.0
  defp decimal_to_float(_), do: 0.0

  @doc """
  Per-device stats for operator detail: today's sales (total / cash / QR), jobs today, hourly buckets.
  """
  def operator_device_stats(params) when is_map(params) do
    device_id =
      case Map.get(params, "device_id") do
        nil ->
          nil

        v when is_binary(v) ->
          case Integer.parse(v) do
            {i, _} -> i
            :error -> nil
          end

        v when is_integer(v) ->
          v
      end

    if device_id == nil do
      %{error: "device_id required"}
    else
      sales_q = """
      SELECT
        COALESCE(SUM(s.amount), 0) AS today_total,
        COALESCE(SUM(s.amount) FILTER (WHERE COALESCE(s.sales_type, '') = 'cash'), 0) AS today_cash,
        COALESCE(
          SUM(s.amount) FILTER (
            WHERE COALESCE(s.sales_type, '') = 'offline'
              OR (s.payment_channel IS NOT NULL AND (
                s.payment_channel ILIKE '%qr%'
                OR s.payment_channel ILIKE '%duitnow%'
                OR s.payment_channel = 'duitnowsqr'
              ))
          ),
          0
        ) AS today_qr
      FROM sales s
      WHERE s.device_id = $1
        AND s.status = 'complete'
        AND DATE((s.inserted_at AT TIME ZONE 'UTC') AT TIME ZONE 'Asia/Kuala_Lumpur')
          = DATE(timezone('Asia/Kuala_Lumpur', now()))
      """

      {:ok, %Postgrex.Result{rows: [sales_row]}} = Repo.query(sales_q, [device_id])

      jobs_q = """
      SELECT COUNT(*)::bigint
      FROM device_logs dl
      WHERE dl.device_id = $1
        AND DATE((dl.inserted_at AT TIME ZONE 'UTC') AT TIME ZONE 'Asia/Kuala_Lumpur')
          = DATE(timezone('Asia/Kuala_Lumpur', now()))
      """

      {:ok, %Postgrex.Result{rows: [[jobs_today]]}} = Repo.query(jobs_q, [device_id])

      hourly_q = """
      SELECT
        EXTRACT(HOUR FROM (s.inserted_at AT TIME ZONE 'UTC') AT TIME ZONE 'Asia/Kuala_Lumpur')::integer AS hr,
        COALESCE(SUM(s.amount), 0) AS total,
        COALESCE(SUM(s.amount) FILTER (WHERE COALESCE(s.sales_type, '') = 'cash'), 0) AS cash,
        COALESCE(
          SUM(s.amount) FILTER (
            WHERE COALESCE(s.sales_type, '') = 'offline'
              OR (s.payment_channel IS NOT NULL AND (
                s.payment_channel ILIKE '%qr%'
                OR s.payment_channel ILIKE '%duitnow%'
                OR s.payment_channel = 'duitnowsqr'
              ))
          ),
          0
        ) AS qr
      FROM sales s
      WHERE s.device_id = $1
        AND s.status = 'complete'
        AND DATE((s.inserted_at AT TIME ZONE 'UTC') AT TIME ZONE 'Asia/Kuala_Lumpur')
          = DATE(timezone('Asia/Kuala_Lumpur', now()))
      GROUP BY 1
      ORDER BY 1
      """

      {:ok, %Postgrex.Result{rows: hourly_rows}} = Repo.query(hourly_q, [device_id])

      hourly_map =
        hourly_rows
        |> Enum.map(fn [hr, total, cash, qr] ->
          h = hr |> :erlang.trunc()

          {h,
           %{
             hour: h,
             total: decimal_to_float(total),
             cash: decimal_to_float(cash),
             qr: decimal_to_float(qr)
           }}
        end)
        |> Map.new()

      hourly =
        Enum.map(0..23, fn h ->
          Map.get(hourly_map, h, %{hour: h, total: 0.0, cash: 0.0, qr: 0.0})
        end)

      [t_total, t_cash, t_qr] = sales_row

      %{
        today_sales_total: decimal_to_float(t_total),
        today_sales_cash: decimal_to_float(t_cash),
        today_sales_qr: decimal_to_float(t_qr),
        jobs_today: jobs_today || 0,
        sales_today_by_hour: hourly
      }
    end
  end

  @doc """
  Organization-wide hourly sales for a calendar day in `Asia/Kuala_Lumpur`.

  * Optional `date` — `YYYY-MM-DD` (default: today in that timezone).
  * Optional `device_id` — restrict to one device.
  """
  def organization_sales_today_by_hour(params) when is_map(params) do
    org_id =
      case Map.get(params, "organization_id") do
        nil ->
          nil

        v when is_binary(v) ->
          case Integer.parse(v) do
            {i, _} -> i
            :error -> nil
          end

        v when is_integer(v) ->
          v
      end

    if org_id == nil do
      []
    else
      local_date =
        case Map.get(params, "date") do
          d when is_binary(d) and d != "" ->
            case Date.from_iso8601(d) do
              {:ok, date} -> date
              :error -> DateTime.now!("Asia/Kuala_Lumpur") |> DateTime.to_date()
            end

          _ ->
            DateTime.now!("Asia/Kuala_Lumpur") |> DateTime.to_date()
        end

      device_id =
        case Map.get(params, "device_id") do
          nil ->
            nil

          "" ->
            nil

          "all" ->
            nil

          v when is_binary(v) ->
            case Integer.parse(v) do
              {i, _} -> i
              :error -> nil
            end

          v when is_integer(v) ->
            v
        end

      {extra_sql, bind} =
        if device_id do
          {
            " AND s.device_id = $3",
            [org_id, local_date, device_id]
          }
        else
          {"", [org_id, local_date]}
        end

      query = """
      SELECT
        EXTRACT(HOUR FROM (s.inserted_at AT TIME ZONE 'UTC') AT TIME ZONE 'Asia/Kuala_Lumpur')::integer AS hr,
        COALESCE(SUM(s.amount), 0) AS total,
        COALESCE(SUM(s.amount) FILTER (WHERE COALESCE(s.sales_type, '') = 'cash'), 0) AS cash,
        COALESCE(
          SUM(s.amount) FILTER (
            WHERE COALESCE(s.sales_type, '') = 'offline'
              OR (s.payment_channel IS NOT NULL AND (
                s.payment_channel ILIKE '%qr%'
                OR s.payment_channel ILIKE '%duitnow%'
                OR s.payment_channel = 'duitnowsqr'
              ))
          ),
          0
        ) AS qr,
        COALESCE(SUM(s.amount) FILTER (WHERE COALESCE(s.sales_type, '') = 'topup'), 0) AS topup
      FROM sales s
      INNER JOIN devices d ON d.id = s.device_id
      WHERE d.organization_id = $1
        AND s.status = 'complete'
        AND DATE((s.inserted_at AT TIME ZONE 'UTC') AT TIME ZONE 'Asia/Kuala_Lumpur') = $2::date
      #{extra_sql}
      GROUP BY 1
      ORDER BY 1
      """

      {:ok, %Postgrex.Result{rows: hourly_rows}} = Repo.query(query, bind)

      hourly_map =
        hourly_rows
        |> Enum.map(fn [hr, total, cash, qr, topup] ->
          h = hr |> :erlang.trunc()

          {h,
           %{
             hour: h,
             label: "#{String.pad_leading(Integer.to_string(h), 2, "0")}:00",
             total: decimal_to_float(total),
             cash: decimal_to_float(cash),
             qr: decimal_to_float(qr),
             topup: decimal_to_float(topup)
           }}
        end)
        |> Map.new()

      Enum.map(0..23, fn h ->
        Map.get(hourly_map, h, %{
          hour: h,
          label: "#{String.pad_leading(Integer.to_string(h), 2, "0")}:00",
          total: 0.0,
          cash: 0.0,
          qr: 0.0,
          topup: 0.0
        })
      end)
    end
  end

  # BlogEngine.Settings.monthly_outlet_trx_only_days()

  def monthly_outlet_trx_only_days(params \\ %{}) do
    organization_id = Map.get(params, "organization_id", nil)

    organization_id =
      if organization_id != nil do
        String.to_integer(organization_id)
      else
        nil
      end

    qparams = ["complete"]
    [y, m, d] = Date.utc_today() |> Date.to_string() |> String.split("-")
    year_month = Map.get(params, "year_month", "#{y}-#{m}")

    organization_q =
      if organization_id != nil do
        """
        and d.organization_id = $2
        """
      else
        """
        """
      end

    qparams = qparams |> List.insert_at(Enum.count(qparams), organization_id)

    # Get the current number of days in the current month
    days_in_month_query = """
      SELECT EXTRACT(DAY FROM (DATE_TRUNC('month', CURRENT_DATE) + INTERVAL '1 MONTH' - INTERVAL '1 DAY'))::INT;
    """

    {:ok, %Postgrex.Result{rows: [[days_in_month]]}} = Repo.query(days_in_month_query, [])

    # Dynamically create FILTER clauses for each day of the current month
    day_filters =
      Enum.map(1..31, fn day ->
        padded_day = String.pad_leading(Integer.to_string(day), 2, "0")

        """
        sum(l.amount) FILTER(WHERE to_char(l.inserted_at, 'YYYY-MM-DD') = '#{year_month}' || '-#{padded_day}') AS day_#{day},
        sum(l.amount) FILTER(WHERE to_char(l.inserted_at, 'YYYY-MM-DD') = '#{year_month}' || '-#{padded_day}' AND l.sales_type = 'offline') AS day_#{day}_online_sum,
        sum(l.amount) FILTER(WHERE to_char(l.inserted_at, 'YYYY-MM-DD') = '#{year_month}' || '-#{padded_day}' AND l.sales_type = 'cash') AS day_#{day}_offline_sum,
        sum(l.amount) FILTER(WHERE to_char(l.inserted_at, 'YYYY-MM-DD') = '#{year_month}' || '-#{padded_day}' AND l.sales_type = 'topup') AS day_#{day}_topup_sum
        """
      end)
      |> Enum.join(",\n")

    query3 = """
    select
        to_char(l.inserted_at, 'YYYY-MM') as year,
        d.short_name as device,
        d.name as device_long,
        count(l.id) as transactions,
        sum(l.amount) as amount,
        count(l.id) FILTER (WHERE l.sales_type = 'offline') as sales_online,
        count(l.id) FILTER (WHERE l.sales_type = 'cash') as sales_offline,
        count(l.id) FILTER (WHERE l.sales_type = 'topup') as sales_topup,
        o.name as outlet,
        COALESCE(oz.name, 'n/a') as organization,
        #{day_filters}
      from
        sales l
        left join devices d on d.id = l.device_id
        left join outlets o on o.id = l.outlet_id
        full join organizations oz on oz.id = d.organization_id
      where
        l.status = $1
        and to_char(l.inserted_at, 'YYYY-MM') = '#{year_month}'
        #{organization_q}
      group by
        d.name, d.short_name, o.name, oz.name, to_char(l.inserted_at, 'YYYY-MM')
      order by
        to_char(l.inserted_at, 'YYYY-MM') desc;
    """

    type = ""

    query =
      case type do
        _ ->
          query3
      end

    {:ok, %Postgrex.Result{columns: columns, rows: rows} = res} =
      Repo.query(query, qparams |> Enum.reject(&(&1 == nil)))

    for row <- rows do
      Enum.zip(columns |> Enum.map(&(&1 |> String.to_atom())), row) |> Enum.into(%{})
    end
    |> IO.inspect()
  end

  def monthly_outlet_trx_only_rp(params \\ %{}) do
    organization_id = Map.get(params, "organization_id", nil)

    organization_id =
      if organization_id != nil do
        String.to_integer(organization_id)
      else
        nil
      end

    qparams = ["complete"]

    organization_q =
      if organization_id != nil do
        """
        and d.organization_id = $2
        """
      else
        """

        """
      end

    qparams = qparams |> List.insert_at(Enum.count(qparams), organization_id)

    query3 = """

    select
        to_char(l.inserted_at, 'YYYY') as year,
        d.short_name as device,
        d.name as device_long,
        count(l.id) as transactions,
        ROUND(COALESCE(sum(l.amount)::numeric, 0), 2) as amount,
        ROUND(COALESCE(sum(l.amount) FILTER(WHERE COALESCE(l.sales_type, '') = 'cash')::numeric, 0), 2) as amount_cash,
        ROUND(
          COALESCE(
            sum(l.amount) FILTER(
              WHERE COALESCE(l.sales_type, '') = 'offline'
                OR (l.payment_channel IS NOT NULL AND (
                  l.payment_channel ILIKE '%qr%'
                  OR l.payment_channel ILIKE '%duitnow%'
                  OR l.payment_channel = 'duitnowsqr'
                ))
            )::numeric,
            0
          ),
          2
        ) as amount_qr,
        ROUND(COALESCE(sum(l.amount) FILTER(WHERE COALESCE(l.sales_type, '') = 'topup')::numeric, 0), 2) as amount_topup,
        o.name as outlet,
        COALESCE(oz.name, 'n/a') as organization,
        ROUND(COALESCE(sum(l.amount) FILTER(WHERE to_char(l.inserted_at, 'MM') = '01')::numeric, 0), 2) AS jan,
        ROUND(COALESCE(sum(l.amount) FILTER(WHERE to_char(l.inserted_at, 'MM') = '02')::numeric, 0), 2) AS feb,
        ROUND(COALESCE(sum(l.amount) FILTER(WHERE to_char(l.inserted_at, 'MM') = '03')::numeric, 0), 2) AS mar,
        ROUND(COALESCE(sum(l.amount) FILTER(WHERE to_char(l.inserted_at, 'MM') = '04')::numeric, 0), 2) AS apr,
        ROUND(COALESCE(sum(l.amount) FILTER(WHERE to_char(l.inserted_at, 'MM') = '05')::numeric, 0), 2) AS may,
        ROUND(COALESCE(sum(l.amount) FILTER(WHERE to_char(l.inserted_at, 'MM') = '06')::numeric, 0), 2) AS jun,
        ROUND(COALESCE(sum(l.amount) FILTER(WHERE to_char(l.inserted_at, 'MM') = '07')::numeric, 0), 2) AS jul,
        ROUND(COALESCE(sum(l.amount) FILTER(WHERE to_char(l.inserted_at, 'MM') = '08')::numeric, 0), 2) AS aug,
        ROUND(COALESCE(sum(l.amount) FILTER(WHERE to_char(l.inserted_at, 'MM') = '09')::numeric, 0), 2) AS sep,
        ROUND(COALESCE(sum(l.amount) FILTER(WHERE to_char(l.inserted_at, 'MM') = '10')::numeric, 0), 2) AS oct,
        ROUND(COALESCE(sum(l.amount) FILTER(WHERE to_char(l.inserted_at, 'MM') = '11')::numeric, 0), 2) AS nov,
        ROUND(COALESCE(sum(l.amount) FILTER(WHERE to_char(l.inserted_at, 'MM') = '12')::numeric, 0), 2) AS dec
      from
        sales l
        left join devices d on d.id = l.device_id
        left join outlets o on o.id = l.outlet_id
        full join organizations oz on oz.id = d.organization_id
      where l.status = $1
      #{organization_q}
      group by d.name, d.short_name, o.name, oz.name, to_char(l.inserted_at, 'YYYY')
      order by to_char(l.inserted_at, 'YYYY') desc;
    """

    type = ""

    query =
      case type do
        _ ->
          query3
      end

    {:ok, %Postgrex.Result{columns: columns, rows: rows} = res} =
      Repo.query(query, qparams |> Enum.reject(&(&1 == nil)))

    for row <- rows do
      IO.inspect(row)
      Enum.zip(columns |> Enum.map(&(&1 |> String.to_atom())), row) |> Enum.into(%{})
    end
  end

  def yearly_sales_performance(type \\ "MY", organization_id) do
    if organization_id == nil do
      query3 = """
      select
        to_char( l.inserted_at , 'YYYY') as year,
        sum(l.amount) FILTER(WHERE to_char( l.inserted_at , 'YYYY') = to_char( l.inserted_at , 'YYYY') and to_char( l.inserted_at , 'MM') = '01') AS jan,
        sum(l.amount) FILTER(WHERE to_char( l.inserted_at , 'YYYY') = to_char( l.inserted_at , 'YYYY') and to_char( l.inserted_at , 'MM') = '02') AS feb,
        sum(l.amount) FILTER(WHERE to_char( l.inserted_at , 'YYYY') = to_char( l.inserted_at , 'YYYY') and to_char( l.inserted_at , 'MM') = '03') AS mar,
        sum(l.amount) FILTER(WHERE to_char( l.inserted_at , 'YYYY') = to_char( l.inserted_at , 'YYYY') and to_char( l.inserted_at , 'MM') = '04') AS apr,
        sum(l.amount) FILTER(WHERE to_char( l.inserted_at , 'YYYY') = to_char( l.inserted_at , 'YYYY') and to_char( l.inserted_at , 'MM') = '05') AS may,
        sum(l.amount) FILTER(WHERE to_char( l.inserted_at , 'YYYY') = to_char( l.inserted_at , 'YYYY') and to_char( l.inserted_at , 'MM') = '06') AS jun,
        sum(l.amount) FILTER(WHERE to_char( l.inserted_at , 'YYYY') = to_char( l.inserted_at , 'YYYY') and to_char( l.inserted_at , 'MM') = '07') AS jul,
        sum(l.amount) FILTER(WHERE to_char( l.inserted_at , 'YYYY') = to_char( l.inserted_at , 'YYYY') and to_char( l.inserted_at , 'MM') = '08') AS aug,
        sum(l.amount) FILTER(WHERE to_char( l.inserted_at , 'YYYY') = to_char( l.inserted_at , 'YYYY') and to_char( l.inserted_at , 'MM') = '09') AS sep,
        sum(l.amount) FILTER(WHERE to_char( l.inserted_at , 'YYYY') = to_char( l.inserted_at , 'YYYY') and to_char( l.inserted_at , 'MM') = '10') AS oct,
        sum(l.amount) FILTER(WHERE to_char( l.inserted_at , 'YYYY') = to_char( l.inserted_at , 'YYYY') and to_char( l.inserted_at , 'MM') = '11') AS nov,
        sum(l.amount) FILTER(WHERE to_char( l.inserted_at , 'YYYY') = to_char( l.inserted_at , 'YYYY') and to_char( l.inserted_at , 'MM') = '12') AS dec
      from
        sales l
        where l.status = $1
        group by to_char( l.inserted_at , 'YYYY') order by to_char( l.inserted_at , 'YYYY') desc ;
      """

      params = ["complete"]

      query =
        case type do
          _ ->
            query3
        end

      {:ok, %Postgrex.Result{columns: columns, rows: rows} = res} = Repo.query(query, params)

      for row <- rows do
        Enum.zip(columns |> Enum.map(&(&1 |> String.to_atom())), row) |> Enum.into(%{})
      end
    else
      query3 = """
      select
        to_char( l.inserted_at , 'YYYY') as year,
        sum(l.amount) FILTER(WHERE to_char( l.inserted_at , 'YYYY') = to_char( l.inserted_at , 'YYYY') and to_char( l.inserted_at , 'MM') = '01') AS jan,
        sum(l.amount) FILTER(WHERE to_char( l.inserted_at , 'YYYY') = to_char( l.inserted_at , 'YYYY') and to_char( l.inserted_at , 'MM') = '02') AS feb,
        sum(l.amount) FILTER(WHERE to_char( l.inserted_at , 'YYYY') = to_char( l.inserted_at , 'YYYY') and to_char( l.inserted_at , 'MM') = '03') AS mar,
        sum(l.amount) FILTER(WHERE to_char( l.inserted_at , 'YYYY') = to_char( l.inserted_at , 'YYYY') and to_char( l.inserted_at , 'MM') = '04') AS apr,
        sum(l.amount) FILTER(WHERE to_char( l.inserted_at , 'YYYY') = to_char( l.inserted_at , 'YYYY') and to_char( l.inserted_at , 'MM') = '05') AS may,
        sum(l.amount) FILTER(WHERE to_char( l.inserted_at , 'YYYY') = to_char( l.inserted_at , 'YYYY') and to_char( l.inserted_at , 'MM') = '06') AS jun,
        sum(l.amount) FILTER(WHERE to_char( l.inserted_at , 'YYYY') = to_char( l.inserted_at , 'YYYY') and to_char( l.inserted_at , 'MM') = '07') AS jul,
        sum(l.amount) FILTER(WHERE to_char( l.inserted_at , 'YYYY') = to_char( l.inserted_at , 'YYYY') and to_char( l.inserted_at , 'MM') = '08') AS aug,
        sum(l.amount) FILTER(WHERE to_char( l.inserted_at , 'YYYY') = to_char( l.inserted_at , 'YYYY') and to_char( l.inserted_at , 'MM') = '09') AS sep,
        sum(l.amount) FILTER(WHERE to_char( l.inserted_at , 'YYYY') = to_char( l.inserted_at , 'YYYY') and to_char( l.inserted_at , 'MM') = '10') AS oct,
        sum(l.amount) FILTER(WHERE to_char( l.inserted_at , 'YYYY') = to_char( l.inserted_at , 'YYYY') and to_char( l.inserted_at , 'MM') = '11') AS nov,
        sum(l.amount) FILTER(WHERE to_char( l.inserted_at , 'YYYY') = to_char( l.inserted_at , 'YYYY') and to_char( l.inserted_at , 'MM') = '12') AS dec
      from
        sales l
        where l.organization_id = $1 and l.status = $2
        group by to_char( l.inserted_at , 'YYYY') order by to_char( l.inserted_at , 'YYYY') desc ;
      """

      params = [organization_id |> String.to_integer(), "complete"]

      query =
        case type do
          _ ->
            query3
        end

      {:ok, %Postgrex.Result{columns: columns, rows: rows} = res} = Repo.query(query, params)

      for row <- rows do
        Enum.zip(columns |> Enum.map(&(&1 |> String.to_atom())), row) |> Enum.into(%{})
      end
    end
  end

  alias BlogEngine.Settings.Firmware

  def list_firmwares() do
    Repo.all(Firmware)
  end

  def get_firmware!(id) do
    Repo.get!(Firmware, id)
  end

  def create_firmware(params \\ %{}) do
    Firmware.changeset(%Firmware{}, params) |> Repo.insert() |> IO.inspect()
  end

  def update_firmware(model, params) do
    Firmware.changeset(model, params) |> Repo.update() |> IO.inspect()
  end

  def delete_firmware(%Firmware{} = model) do
    Repo.delete(model)
  end

  alias BlogEngine.Settings.FirmwareLog

  def list_firmware_logs() do
    Repo.all(FirmwareLog)
  end

  def get_firmware_log!(id) do
    Repo.get!(FirmwareLog, id)
  end

  def create_firmware_log(params \\ %{}) do
    FirmwareLog.changeset(%FirmwareLog{}, params) |> Repo.insert() |> IO.inspect()
  end

  def update_firmware_log(model, params) do
    FirmwareLog.changeset(model, params) |> Repo.update() |> IO.inspect()
  end

  def delete_firmware_log(%FirmwareLog{} = model) do
    Repo.delete(model)
  end

  alias BlogEngine.Settings.Subscription

  def list_subscriptions() do
    Repo.all(Subscription)
  end

  def get_subscription!(id) do
    Repo.get!(Subscription, id)
  end

  def create_subscription(params \\ %{}) do
    Subscription.changeset(%Subscription{}, params) |> Repo.insert() |> IO.inspect()
  end

  def update_subscription(model, params) do
    Subscription.changeset(model, params) |> Repo.update() |> IO.inspect()
  end

  def delete_subscription(%Subscription{} = model) do
    Repo.delete(model)
  end

  alias BlogEngine.Settings.OutletSubscription

  def list_outlet_subscriptions() do
    Repo.all(OutletSubscription)
  end

  def get_outlet_subscription!(id) do
    Repo.get!(OutletSubscription, id) |> Repo.preload([:outlet])
  end

  def create_outlet_subscription(params \\ %{}) do
    params =
      if params["subscription_id"] != nil do
        subscription = get_subscription!(params["subscription_id"])
        device = get_device!(params["device_id"])

        start_date =
          if params["start_date"] in [nil, ""], do: Date.utc_today(), else: params["start_date"]

        end_date =
          if params["end_date"] in [nil, ""],
            do: Timex.shift(Date.utc_today(), months: subscription.duration_in_months),
            else: params["end_date"]

        params
        |> Map.merge(%{
          "amount" => subscription.amount,
          "outlet_id" => device.outlet_id,
          "start_date" => start_date,
          "end_date" => end_date
        })
      else
        device = get_device!(params["device_id"])

        start_date =
          if params["start_date"] in [nil, ""], do: Date.utc_today(), else: params["start_date"]

        end_date =
          if params["end_date"] in [nil, ""], do: Date.utc_today(), else: params["end_date"]

        params
        |> Map.merge(%{
          "amount" => 0,
          "outlet_id" => device.outlet_id,
          "start_date" => start_date,
          "end_date" => end_date
        })
      end

    OutletSubscription.changeset(%OutletSubscription{}, params) |> Repo.insert() |> IO.inspect()
  end

  def update_outlet_subscription(model, params) do
    params =
      if params["subscription_id"] != nil do
        subscription = get_subscription!(params["subscription_id"])
        device = get_device!(params["device_id"])

        amount =
          if params["amount"] != nil and params["amount"] != "" do
            params["amount"]
          else
            subscription.amount
          end

        start_date =
          if params["start_date"] in [nil, ""], do: Date.utc_today(), else: params["start_date"]

        end_date =
          if params["end_date"] in [nil, ""],
            do: Timex.shift(Date.utc_today(), months: subscription.duration_in_months),
            else: params["end_date"]

        params
        |> Map.merge(%{
          "amount" => amount,
          "outlet_id" => device.outlet_id,
          "start_date" => start_date,
          "end_date" => end_date
        })
      else
        params =
          if params["device_id"] != nil do
            device = get_device!(params["device_id"])

            start_date =
              if params["start_date"] in [nil, ""],
                do: Date.utc_today(),
                else: params["start_date"]

            end_date =
              if params["end_date"] in [nil, ""], do: Date.utc_today(), else: params["end_date"]

            params
            |> Map.merge(%{
              "amount" => 0,
              "outlet_id" => device.outlet_id,
              "start_date" => start_date,
              "end_date" => end_date
            })
          else
            params
          end
      end

    OutletSubscription.changeset(model, params) |> Repo.update() |> IO.inspect()
  end

  def delete_outlet_subscription(%OutletSubscription{} = model) do
    Repo.delete(model)
  end

  alias BlogEngine.Settings.Invoice

  def list_invoices() do
    Repo.all(Invoice)
  end

  def get_invoice!(id) do
    Repo.get!(Invoice, id) |> Repo.preload([:organization, :outlet_subscriptions, :outlets])
  end

  def get_invoice_with_details!(id) do
    Repo.get!(Invoice, id)
    |> Repo.preload([:organization, outlet_subscriptions: [:device, :outlet]])
  end

  def get_invoice_by_payment_url(url) do
    Repo.get_by(Invoice, payment_url: url)
    |> Repo.preload([:organization, :outlet_subscriptions, :outlets])
  end

  def create_invoice(params \\ %{}) do
    params =
      params
      |> Map.put(
        "ref_no",
        (fn ->
           year = Date.utc_today().year
           year_start = NaiveDateTime.new!(year, 1, 1, 0, 0, 0)
           next_year_start = NaiveDateTime.new!(year + 1, 1, 1, 0, 0, 0)

           year_count =
             Repo.aggregate(
               from(i in Invoice,
                 where: i.inserted_at >= ^year_start and i.inserted_at < ^next_year_start
               ),
               :count,
               :id
             )

           seq = year_count + 1
           seq_str = seq |> Integer.to_string() |> String.pad_leading(3, "0")
           "INV-#{year}-#{seq_str}"
         end).()
      )

    case Invoice.changeset(%Invoice{}, params) |> Repo.insert() |> IO.inspect() do
      {:ok, inv} ->
        outlets =
          Repo.all(
            from(o in BlogEngine.Settings.Outlet, where: o.organization_id == ^inv.organization_id)
          )

        devices =
          Repo.all(
            from(d in BlogEngine.Settings.Device,
              where: d.outlet_id in ^Enum.map(outlets, & &1.id)
            )
          )

        for device <- devices do
          create_outlet_subscription(%{
            "invoice_id" => inv.id,
            "device_id" => device.id
          })
        end

        {:ok, inv}

      {:error, cg} ->
        {:error, cg}
    end
  end

  @doc """
  Creates one unpaid invoice and a single outlet subscription line for the given
  device and subscription plan (no per-organization device fan-out).
  """
  def create_invoice_for_subscription_plan(%{
        "organization_id" => org_id,
        "subscription_id" => sub_id,
        "device_id" => device_id
      })
      when is_integer(org_id) and is_integer(sub_id) and is_integer(device_id) do
    device = get_device!(device_id)

    if device.organization_id != org_id do
      {:error, :device_org_mismatch}
    else
      subscription = get_subscription!(sub_id)

      ref_no =
        (fn ->
           year = Date.utc_today().year
           year_start = NaiveDateTime.new!(year, 1, 1, 0, 0, 0)
           next_year_start = NaiveDateTime.new!(year + 1, 1, 1, 0, 0, 0)

           year_count =
             Repo.aggregate(
               from(i in Invoice,
                 where: i.inserted_at >= ^year_start and i.inserted_at < ^next_year_start
               ),
               :count,
               :id
             )

           seq = year_count + 1
           seq_str = seq |> Integer.to_string() |> String.pad_leading(3, "0")
           "INV-#{year}-#{seq_str}"
         end).()

      due_date = Date.utc_today() |> Date.add(14)

      invoice_attrs = %{
        "organization_id" => org_id,
        "status" => "pending",
        "grand_total" => subscription.amount,
        "due_date" => due_date,
        "remarks" => "Subscription plan: #{subscription.name}",
        "ref_no" => ref_no
      }

      Multi.new()
      |> Multi.insert(:invoice, Invoice.changeset(%Invoice{}, invoice_attrs))
      |> Multi.run(:outlet_subscription, fn _repo, %{invoice: inv} ->
        create_outlet_subscription(%{
          "invoice_id" => inv.id,
          "device_id" => device_id,
          "subscription_id" => sub_id
        })
      end)
      |> Repo.transaction()
      |> IO.inspect(label: "Repo.transaction")
      |> case do
        {:ok, %{invoice: inv, outlet_subscription: os}} ->
          {:ok, %{invoice: inv, outlet_subscription: os}}

        {:ok, %{outlet_subscription: {:error, cg}}} ->
          {:error, cg}

        {:error, _step, failed_val, _changes} ->
          {:error, failed_val}

        other ->
          {:error, other}
      end
    end
  end

  @doc """
  Staff-only flow: validate org and ids, then create invoice + outlet subscription line.
  Caller must ensure `staff` matches the authenticated subject from `ApiAuthorization` (`:api_auth`).
  """
  def operator_subscribe_plan_for_staff(%Staff{} = staff, params) when is_map(params) do
    cond do
      staff.organization_id == nil ->
        {:error, "Your account has no organization."}

      true ->
        with {:ok, org_id} <- parse_operator_subscribe_id(params["organization_id"]),
             {:ok, sub_id} <- parse_operator_subscribe_id(params["subscription_id"]),
             {:ok, device_id} <- parse_operator_subscribe_id(params["device_id"]) do
          if staff.organization_id != org_id do
            {:error, "You can only subscribe for your own organization."}
          else
            case create_invoice_for_subscription_plan(%{
                   "organization_id" => org_id,
                   "subscription_id" => sub_id,
                   "device_id" => device_id
                 })
                 |> IO.inspect(label: "create_invoice_for_subscription_plan") do
              {:ok, %{invoice: inv, outlet_subscription: outlet_subscription}} ->
                {:ok, %{status: "ok", invoice_id: inv.id, ref_no: inv.ref_no}}

              {:error, :device_org_mismatch} ->
                {:error, "Device does not belong to your organization."}

              {:error, %Ecto.Changeset{} = cg} ->
                {:error, format_operator_subscribe_changeset_errors(cg)}

              {:error, other} ->
                {:error, inspect(other)}
            end
          end
        else
          _ -> {:error, "Invalid organization, subscription, or device id."}
        end
    end
  end

  defp parse_operator_subscribe_id(v) when is_integer(v) and v > 0, do: {:ok, v}

  defp parse_operator_subscribe_id(v) when is_binary(v) do
    case Integer.parse(String.trim(v)) do
      {i, _} when i > 0 -> {:ok, i}
      _ -> {:error, :invalid_id}
    end
  end

  defp parse_operator_subscribe_id(_), do: {:error, :invalid_id}

  defp format_operator_subscribe_changeset_errors(cg) do
    Ecto.Changeset.traverse_errors(cg, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> Enum.map(fn {k, v} -> "#{k} #{inspect(v)}" end)
    |> Enum.join("; ")
  end

  def update_invoice(model, params) do
    Invoice.changeset(model, params) |> Repo.update() |> IO.inspect()
  end

  def delete_invoice(%Invoice{} = model) do
    Repo.delete(model)
  end

  alias BlogEngine.Settings.UserTopup

  def list_user_topups() do
    Repo.all(UserTopup)
  end

  def get_user_topup!(id) do
    Repo.get!(UserTopup, id)
  end

  def get_user_topup_by_user_and_organization(user_id, organization_id)
      when is_integer(user_id) and is_integer(organization_id) do
    Repo.get_by(UserTopup, user_id: user_id, organization_id: organization_id)
    |> IO.inspect(label: "UTPUT")
  end

  def get_user_topup_by_user_and_organization(_, _), do: nil

  def create_user_topup(params \\ %{}) do
    UserTopup.changeset(%UserTopup{}, params) |> Repo.insert() |> IO.inspect()
  end

  def update_user_topup(model, params) do
    UserTopup.changeset(model, params) |> Repo.update() |> IO.inspect()
  end

  def delete_user_topup(%UserTopup{} = model) do
    Repo.delete(model)
  end

  def complete_topup(topup_sale) do
    paid = to_float_2dp(topup_sale.amount)
    credit = topup_promo_credit_amount(paid)
    bonus = topup_promo_bonus_amount(paid)

    remarks =
      if bonus > 0 do
        "Topup payment (#{format_rm_whole(paid)}+#{format_rm_whole(bonus)} promo)"
      else
        "Topup payment"
      end

    Multi.new()
    |> Multi.run(:user_topup_multi, fn _repo, %{} ->
      multi_res =
        BlogEngine.Settings.create_user_topup_transaction(%{
          user_id: Map.get(topup_sale, :user_id),
          organization_id: topup_sale.organization_id,
          amount: credit,
          remarks: remarks,
          sales_id: topup_sale.id,
          device_log_id: nil
        })

      multi_res
    end)
    |> Multi.run(:sale_update, fn _repo, _changes ->
      BlogEngine.Settings.update_sale(topup_sale, %{status: :complete})
    end)
    |> Repo.transaction()
    |> case do
      {:ok, multi_res} ->
        {:ok, multi_res}

      {:error, _step, failed_val, _changes} ->
        {:error, failed_val}

      other ->
        {:error, other}
    end
  end

  defp topup_promo_bonus_map do
    %{1.0 => 0.0, 10.0 => 1.0, 20.0 => 2.0, 50.0 => 5.0, 100.0 => 10.0}
  end

  @doc """
  JSON-safe tier list for mobile apps (`get_topup_promo_tiers` webhook).
  Must stay in sync with `topup_promo_bonus_amount/1` used when completing top-up sales.
  """
  def topup_promo_tiers_for_api do
    topup_promo_bonus_map()
    |> Enum.sort_by(fn {k, _} -> k end)
    |> Enum.map(fn {rm, bonus} ->
      %{
        "rm" => rm |> to_float_2dp() |> :erlang.trunc(),
        "bonus" => bonus |> to_float_2dp() |> :erlang.trunc()
      }
    end)
  end

  defp topup_promo_bonus_amount(paid) when is_number(paid) do
    p = to_float_2dp(paid)
    Map.get(topup_promo_bonus_map(), p, 0.0)
  end

  defp topup_promo_credit_amount(paid) when is_number(paid) do
    paid = to_float_2dp(paid)
    (paid + topup_promo_bonus_amount(paid)) |> to_float_2dp()
  end

  defp format_rm_whole(n) when is_number(n) do
    n |> to_float_2dp() |> :erlang.trunc() |> Integer.to_string()
  end

  alias BlogEngine.Settings.UserTopupTransaction

  @doc """
  Latest ledger rows for a member within one organization (via `user_topups`).
  """
  def list_recent_user_topup_transactions(user_id, organization_id, limit \\ 5)
      when is_integer(user_id) and is_integer(organization_id) and is_integer(limit) do
    from(t in UserTopupTransaction,
      join: ut in UserTopup,
      on: t.user_topup_id == ut.id,
      where: ut.user_id == ^user_id and ut.organization_id == ^organization_id,
      order_by: [desc: t.inserted_at],
      limit: ^limit,
      select: t
    )
    |> Repo.all()
  end

  def list_user_topup_transactions() do
    Repo.all(UserTopupTransaction)
  end

  def get_user_topup_transaction!(id) do
    Repo.get!(UserTopupTransaction, id)
  end

  def create_user_topup_transaction(params \\ %{}) do
    params = normalize_user_topup_transaction_params(params)

    Multi.new()
    |> Multi.run(:user_topup, fn _repo, %{} ->
      user_id = Map.fetch!(params, :user_id)
      organization_id = Map.fetch!(params, :organization_id)

      case Repo.get_by(UserTopup, user_id: user_id, organization_id: organization_id) do
        %UserTopup{} = ut ->
          {:ok, ut}

        nil ->
          case create_user_topup(%{
                 user_id: user_id,
                 organization_id: organization_id,
                 balance: 0.0
               }) do
            {:ok, %UserTopup{} = ut} -> {:ok, ut}
            {:error, cg} -> {:error, cg}
          end
      end
    end)
    |> Multi.run(:user_topup_transaction, fn _repo, %{user_topup: %UserTopup{} = ut} ->
      amount = Map.fetch!(params, :amount) |> to_float_2dp()
      before_amt = (ut.balance || 0.0) |> to_float_2dp()
      after_amt = (before_amt + amount) |> to_float_2dp()

      attrs =
        params
        |> Map.put(:user_topup_id, ut.id)
        |> Map.put(:before_amt, before_amt)
        |> Map.put(:after_amt, after_amt)

      UserTopupTransaction.changeset(%UserTopupTransaction{}, attrs) |> Repo.insert()
    end)
    |> Multi.run(:user_topup_update, fn _repo,
                                        %{
                                          user_topup: %UserTopup{} = ut,
                                          user_topup_transaction: %UserTopupTransaction{} = trx
                                        } ->
      UserTopup.changeset(ut, %{balance: trx.after_amt}) |> Repo.update()
    end)
    |> Repo.transaction()
    |> IO.inspect()
    |> case do
      {:ok, multi_res} ->
        trx = Map.get(multi_res, :user_topup_transaction)

        if trx.amount > 0 do
          trx = Repo.preload(trx, :organization)

          # organization = BlogEngine.Settings.get_user_topup_transaction!() |> BlogEngine.Repo.preload(:organization) |> Map.get(:organization)
          organization = trx |> Map.get(:organization)

          Task.start(fn ->
            fcm_notify_org_operators_topup(organization.id, trx.user_id, trx.amount)
          end)
        end

        {:ok, trx}

      {:error, _step, failed_val, _changes} ->
        {:error, failed_val}

      other ->
        {:error, other}
    end
  end

  defp normalize_user_topup_transaction_params(params) when is_map(params) do
    params =
      cond do
        Map.has_key?(params, :user_id) ->
          params

        true ->
          for {k, v} <- params, into: %{}, do: {to_string(k), v}
      end

    %{
      user_id: params[:user_id] || params["user_id"],
      organization_id: params[:organization_id] || params["organization_id"],
      amount: params[:amount] || params["amount"],
      remarks: params[:remarks] || params["remarks"],
      sales_id: params[:sales_id] || params["sales_id"],
      device_log_id: params[:device_log_id] || params["device_log_id"]
    }
  end

  defp normalize_user_topup_transaction_params(_), do: %{}

  defp to_float_2dp(v) when is_float(v), do: Float.round(v, 2)
  defp to_float_2dp(v) when is_integer(v), do: (v * 1.0) |> Float.round(2)

  defp to_float_2dp(v) when is_binary(v) do
    case Float.parse(String.trim(v)) do
      {f, _} -> Float.round(f, 2)
      _ -> 0.0
    end
  end

  defp to_float_2dp(_), do: 0.0

  def update_user_topup_transaction(model, params) do
    UserTopupTransaction.changeset(model, params) |> Repo.update() |> IO.inspect()
  end

  def delete_user_topup_transaction(%UserTopupTransaction{} = model) do
    Repo.delete(model)
  end

  alias BlogEngine.Settings.IoReading

  def list_io_readings() do
    Repo.all(IoReading)
  end

  def get_io_reading!(id) do
    Repo.get!(IoReading, id)
  end

  @doc """
  BlogEngine.Settings.create_io_reading(%{
    device_id: 18,
    log: %{"frequency" => 30,"is_consistent" => true,"pin" => 25,"pulse_count" => 3} |> Jason.encode!,
    final_data: "3"
  })
  """
  def create_io_reading(params \\ %{}) do
    res = IoReading.changeset(%IoReading{}, params) |> Repo.insert() |> IO.inspect()

    Elixir.Task.start_link(__MODULE__, :convert_io_reading_task, [res])
    res
  end

  def update_io_reading(model, params) do
    IoReading.changeset(model, params) |> Repo.update() |> IO.inspect()
  end

  def delete_io_reading(%IoReading{} = model) do
    Repo.delete(model)
  end

  alias BlogEngine.Settings.ReadingConversion

  def list_reading_conversions() do
    Repo.all(ReadingConversion)
  end

  def get_reading_conversion!(id) do
    Repo.get!(ReadingConversion, id)
  end

  def create_reading_conversion(params \\ %{}) do
    ReadingConversion.changeset(%ReadingConversion{}, params) |> Repo.insert() |> IO.inspect()
  end

  def update_reading_conversion(model, params) do
    ReadingConversion.changeset(model, params) |> Repo.update() |> IO.inspect()
  end

  def delete_reading_conversion(%ReadingConversion{} = model) do
    Repo.delete(model)
  end

  def convert_io_reading_task(res) do
    table = Repo.all(ReadingConversion) |> IO.inspect(label: "table")

    case res do
      {:ok, io_reading} ->
        io_reading = io_reading |> Repo.preload(device: :outlet)

        Multi.new()
        |> Multi.run(:sales, fn _repo, %{} ->
          amt = 0

          # 4
          reading =
            case io_reading.final_data |> Integer.parse() do
              {amt, _suffix} ->
                amt

              _ ->
                0
            end
            |> IO.inspect(label: "reading")

          res =
            table
            |> Enum.filter(&(&1.reading_start <= reading and &1.reading_end >= reading))
            |> IO.inspect(label: "res")
            |> List.first()

          amt =
            if res != nil do
              Map.get(res, :converted_data)
            else
              0
            end

          create_sale(%{
            uid: Ecto.UUID.generate(),
            amount: amt,
            outlet_id: io_reading.device.outlet.id,
            organization_id: io_reading.device.organization_id,
            device_id: io_reading.device.id,
            payment_channel: "cash",
            sales_date: Date.utc_today(),
            payment_ref: "io_reading:#{io_reading.id}",
            sales_type: "cash",
            status: "complete"
          })
        end)
        |> Multi.run(:io, fn _repo, %{} ->
          update_io_reading(io_reading, %{is_processed: true})
        end)
        |> Repo.transaction()

      _ ->
        nil
    end
  end

  def convert_unprocessed_io_reading() do
    table = Repo.all(ReadingConversion) |> IO.inspect(label: "table")

    io_readings =
      Repo.all(from(ir in IoReading, where: ir.is_processed != true, preload: [device: :outlet]))

    for io_reading <- io_readings do
      Multi.new()
      |> Multi.run(:sales, fn _repo, %{} ->
        amt = 0

        # 4
        reading =
          case io_reading.final_data |> Integer.parse() do
            {amt, _suffix} ->
              amt

            _ ->
              0
          end
          |> IO.inspect(label: "reading")

        res =
          table
          |> Enum.filter(&(&1.reading_start <= reading and &1.reading_end >= reading))
          |> IO.inspect(label: "res")
          |> List.first()

        amt =
          if res != nil do
            Map.get(res, :converted_data)
          else
            0
          end

        create_sale(%{
          uid: Ecto.UUID.generate(),
          amount: amt,
          outlet_id: io_reading.device.outlet.id,
          organization_id: io_reading.device.organization_id,
          device_id: io_reading.device.id,
          payment_channel: "cash",
          sales_date: Date.utc_today(),
          payment_ref: "io_reading:#{io_reading.id}",
          sales_type: "cash",
          status: "complete"
        })
      end)
      |> Multi.run(:io, fn _repo, %{} ->
        update_io_reading(io_reading, %{is_processed: true})
      end)
      |> Repo.transaction()
    end
  end

  def get_organization_summary(organization_id) do
    case Integer.parse(organization_id) do
      :error ->
        %Organization{
          id: 0,
          name: "DJTECH",
          address: "Malaysia",
          phone: "0",
          contact_person: "DJTECH",
          desc: "IOT",
          img_url: "",
          reg_no: "0",
          bank_name: "",
          bank_acc_no: "",
          bank_holder_name: "",
          inserted_at: NaiveDateTime.utc_now(),
          updated_at: NaiveDateTime.utc_now(),
          outlets: Repo.all(from(o in Outlet, preload: [:devices]))
        }

      _ ->
        Repo.get_by(Organization, id: organization_id) |> Repo.preload(outlets: [:devices])
    end
    |> IO.inspect(label: "summar")
  end
end
