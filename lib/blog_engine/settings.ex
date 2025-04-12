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
    if bool_key in Map.keys(params) do
      params |> Map.put(bool_key, Map.get(params, bool_key) == "on")
    else
      params |> Map.put(bool_key, false)
    end
  end

  alias BlogEngine.Settings.Organization

  def list_organizations() do
    Repo.all(Organization)
  end

  def get_organization!(id) do
    Repo.get!(Organization, id)
  end

  def create_organization(params \\ %{}) do
    Organization.changeset(%Organization{}, params) |> Repo.insert() |> IO.inspect()
  end

  def update_organization(model, params) do
    Organization.changeset(model, params) |> Repo.update() |> IO.inspect()
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
    Device.changeset(model, params) |> Repo.update() |> IO.inspect()
  end

  def delete_device(%Device{} = model) do
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

  def get_cookie_user_by_cookie(cookie) do
    Repo.all(
      from(s in SessionUser,
        where: s.cookie == ^cookie,
        preload: [user: [:organization, role: :app_routes]]
      )
    )
    |> List.first()
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
      user = user |> Repo.preload([:merchant, :rank, :stockist_users])
      {:ok, user}
    else
      _ ->
        {:error}
    end
  end

  def auth_user(params) do
    res =
      Repo.all(
        from(u in User,
          where: u.username == ^params["username"],
          preload: [:merchant, :rank, :stockist_users]
        )
      )

    user = res |> List.first()

    with true <- user != nil,
         crypted_password <-
           :crypto.hash(:sha512, params["password"]) |> Base.encode16() |> String.downcase(),
         true <- crypted_password == user.crypted_password do
      {:ok, user}
    else
      _ ->
        {:error, res}
    end
  end

  def list_users() do
    Repo.all(User)
  end

  def get_user!(id) do
    Repo.all(from(u in User, where: u.id == ^id, preload: [:rank, :merchant])) |> List.first()
  end

  def create_user(attrs \\ %{}) do
    attrs =
      if "password" in Map.keys(attrs) do
        crypted_password =
          :crypto.hash(:sha512, attrs["password"]) |> Base.encode16() |> String.downcase()

        attrs |> Map.put("crypted_password", crypted_password)
      else
        attrs
      end

    User.changeset(%User{}, attrs) |> Repo.insert() |> IO.inspect()
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
  tokens = [token, token2, token3]


  Enum.map(tokens, &   BlogEngine.Settings.fcm_publish(0, "Salam Dari DJTECH", "Anda boleh periksa keadaan mesin dari sini", &1))
  """
  def fcm_publish(
        id,
        title,
        body,
        device_token \\ "cXh-Hxbk88EuxnkpTuDySj:APA91bGZombjdutaWzQomruMWYclBo1JGnhg_V6fGAuZ5_RIrFzrWXDx_qnTC2_q66RJJUuFhV-I3V2RtQD7ffStOq8xuT19fejsNNj0kR-isS5qcE_5JKQ"
      ) do
    access_token = Goth.fetch!(BlogEngine.Goth).token

    if device_token != nil do
      message = %{
        "message" => %{
          "token" => device_token,
          "notification" => %{
            "title" => title,
            "body" => body
          },
          "data" => %{
            "id" => "#{id}",
            "path" => "orders",
            "created_at" => Date.utc_today(),
            "click_action" => "FLUTTER_NOTIFICATION_CLICK"
          }
        }
      }

      # todo, check the error, then delete the access token
      test_message = %{
        "message" => %{
          "token" =>
            "dROnDZkGQPm4357TH__VXI:APA91bEpRxZL7bY-piD5jhfqZ-Ce0BIfDlB1EMyioNnv_29mcC9XdoVXKhM9GBI132m2HzUMCiuliDdMcHcW7FBBwcYHw3CFbVNKLt63469zhsq5tFBtM7o",
          "notification" => %{
            "title" => "Salam Dari DJTECH",
            "body" => "Anda boleh periksa keadaan mesin dari sini2"
          },
          "data" => %{
            "id" => "0",
            "path" => "orders",
            "created_at" => Date.utc_today(),
            "click_action" => "FLUTTER_NOTIFICATION_CLICK"
          }
        }
      }

      res =
        HTTPoison.post(
          "https://fcm.googleapis.com/v1/projects/djtech-655dd/messages:send",
          message |> Jason.encode!(),
          [
            {"content-type", "application/json"},
            {"Authorization", "Bearer #{access_token}"}
          ]
        )

      case res do
        {:ok, %HTTPoison.Response{body: body}} ->
          keys = Jason.decode!(body) |> Map.keys()

          if "error" in keys do
            if device_token != nil do
              Repo.delete_all(
                from(md in BlogEngine.Settings.MessagingDevice, where: md.uuid == ^device_token)
              )
            else
              IO.inspect("no device token, #{body}")
            end
          end

        _ ->
          nil
      end
    else
      IO.inspect("no device token, #{body}")
    end
  end

  def update_messaging_device(model, params) do
    MessagingDevice.changeset(model, params) |> Repo.update() |> IO.inspect()
  end

  def delete_messaging_device(%MessagingDevice{} = model) do
    Repo.delete(model)
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
        sum(l.amount) FILTER(WHERE to_char(l.inserted_at, 'YYYY-MM-DD') = '#{year_month}' || '-#{padded_day}' AND l.sales_type = 'cash') AS day_#{day}_offline_sum
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
