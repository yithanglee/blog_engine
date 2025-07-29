defmodule BlogEngineWeb.ApiController do
  use BlogEngineWeb, :controller

  alias BlogEngine.{Repo, Settings}
  require Logger
  require IEx

  def ngrok_post(conn, params) do
    final =
      case params["scope"] do
        _ ->
          %{status: "received"}
      end

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(final))
  end

  def get_channel_data(%{waited: waited} = x, receiver) do
    # %{waited: 1, content: ""}
    IO.inspect(x)
    Process.sleep(1000)

    pid = Process.whereis(:ngrok)

    content =
      with true <- pid != nil,
           res <- Agent.get(pid, fn map -> Map.get(map, receiver) end) do
        res
      else
        _ ->
          ""
      end
      |> IO.inspect()

    x |> Map.put(:waited, waited + 1) |> Map.put(:content, content)
  end

  @doc """
  send data like 
  http://localhost:8512/ngrok/webhook?receiver=mines_massage_2&url=http://localhost:8501/api/webhook?scope=blogs&params=
  """
  def ngrok_get(conn, params) do
    final =
      case params["scope"] do
        _ ->
          BlogEngineWeb.Endpoint.broadcast(
            "user:#{params["receiver"]}",
            "http_client",
            params |> Map.put("method", "get")
          )

          %{status: "received"}
      end

    conn =
      conn
      |> put_resp_content_type("application/json")
      |> send_chunked(200)

    Enum.reduce_while(
      Stream.iterate(
        %{waited: 1, content: ""},
        fn x ->
          get_channel_data(x, params["receiver"])
        end
      ),
      conn,
      fn chunk, conn ->
        if chunk.content == nil || chunk.waited == 5 do
          IO.inspect("content nillified")
          {:halt, conn}
        else
          case Plug.Conn.chunk(conn, chunk.content) do
            {:ok, conn} ->
              if chunk.content != "" do
                pid = Process.whereis(:ngrok)

                with true <- pid != nil do
                  Agent.update(pid, fn map -> Map.put(map, params["receiver"], nil) end)
                else
                  _ ->
                    ""
                end
              end

              {:cont, conn}

            {:error, :closed} ->
              {:halt, conn}
          end
        end
      end
    )
  end

  def stream_get(conn, params) do
    final =
      case params["scope"] do
        _ ->
          rest_id = Map.get(params, "rest_id", 1)
          pid = Process.whereis(String.to_atom("rest_#{rest_id}"))

          if pid == nil do
            {:ok, pid} = Agent.start_link(fn -> [] end)
            Process.register(pid, String.to_atom("rest_#{rest_id}"))
          else
            IO.inspect("pid rest_#{rest_id} already exist")
          end

          %{status: "received"}
      end

    conn =
      conn
      |> put_resp_content_type("application/json")
      |> send_chunked(200)

    Enum.reduce_while(
      Stream.iterate(
        "",
        fn x ->
          Process.sleep(2000)
          BlogEngine.get_order() |> Jason.encode!()
        end
      ),
      conn,
      fn chunk, conn ->
        IO.inspect(chunk)

        case Plug.Conn.chunk(conn, chunk) do
          {:ok, conn} ->
            {:cont, conn}

          {:error, :closed} ->
            {:halt, conn}
        end
      end
    )
  end

  def decode_token(token) do
    Settings.decode_token(token)
  end

  def csrf(conn, params) do
    json(conn, Phoenix.Controller.get_csrf_token())
  end

  def get(conn, params) do
    # can get data from conn.private.plug_session
    token = params |> Map.get("token")

    %{id: id} =
      with true <- token != nil,
           decoded <- token |> decode_token,
           true <- decoded != nil do
        decoded
      else
        _ ->
          %{id: 0}
      end

    res =
      case params["scope"] do
        "get_create_device" ->
          Settings.create_update_device(params)
          |> BluePotion.sanitize_struct()

        "get_organization_summary" ->
          Settings.get_organization_summary(params["organization_id"])
          |> BluePotion.sanitize_struct()

        "get_time" ->
          timestamp = DateTime.utc_now() |> DateTime.to_unix()
          %{time: timestamp}

        "pay_service_test" ->
          outlet_item = Settings.get_item!(params["id"]) |> BluePotion.sanitize_struct()
          device = Settings.get_device_by_name(params["device"])

          {:ok, s} =
            Settings.create_sale(%{
              sales_date: Date.utc_today(),
              outlet_id: outlet_item.outlet.id,
              organization_id: device.organization_id,
              device_id: device.id,
              amount: outlet_item.price,
              status: :pending_payment,
              uid: Ecto.UUID.generate()
            })

          Settings.create_sales_item(%{
            item_id: outlet_item.id,
            sales_id: s.id,
            item_amount: outlet_item.price,
            item_name: outlet_item.name,
            qty: 1,
            subtotal: outlet_item.price * 1
          })

          sig =
            Ipay88.send_payment_request_test(
              1.00,
              outlet_item.outlet.mkey,
              outlet_item.outlet.mcode,
              "#{Application.get_env(:blog_engine, :revenue_monster)[:prefix]}#{s.id}"
            )

          [sig, "#{Application.get_env(:blog_engine, :revenue_monster)[:prefix]}#{s.id}"]

        "pay_service" ->
          outlet_item = Settings.get_item!(params["id"]) |> BluePotion.sanitize_struct()
          device = Settings.get_device_by_name(params["device"]) |> IO.inspect()

          # todo: check the connection health, last 10 seconds was there any count...
          with true <- device != nil,
               res <-
                 BlogEngine.Settings.check_last_mins(device.id, device.is_cloridge)
                 |> IO.inspect(),
               true <- res <= 60 do
            {:ok, s} =
              Settings.create_sale(%{
                sales_date: Date.utc_today(),
                outlet_id: outlet_item.outlet.id,
                device_id: device.id,
                organization_id: device.organization_id,
                amount: outlet_item.price,
                status: :pending_payment,
                uid: Ecto.UUID.generate()
              })

            Settings.create_sales_item(%{
              item_id: outlet_item.id,
              sales_id: s.id,
              item_amount: outlet_item.price,
              item_name: outlet_item.name,
              qty: 1,
              subtotal: outlet_item.price * 1
            })

            # return url to make payment
            case outlet_item.outlet.payment_gateway do
              "fiuu" ->
                nil
                chan = "FPX"
                server_url = Application.get_env(:blog_engine, :url)

                payment_url =
                  "#{server_url}/test_razer?chan=#{chan}&amt=#{(outlet_item.price * 1) |> :erlang.float_to_binary(decimals: 2)}&ref_no=#{Application.get_env(:blog_engine, :revenue_monster)[:prefix]}#{s.id}"

              "ipay88" ->
                # Ipay88.send_payment_request(
                #   1.00,
                #   outlet_item.outlet.mkey,
                #   outlet_item.outlet.mcode,
                #   "#{Application.get_env(:blog_engine, :revenue_monster)[:prefix]}#{s.id}"
                # )

                sig =
                  Ipay88.send_payment_request_test(
                    1.00,
                    outlet_item.outlet.mkey,
                    outlet_item.outlet.mcode,
                    "#{Application.get_env(:blog_engine, :revenue_monster)[:prefix]}#{s.id}"
                  )

                [
                  sig,
                  "#{Application.get_env(:blog_engine, :revenue_monster)[:prefix]}#{s.id}",
                  outlet_item.outlet.mcode
                ]

              _ ->
                res =
                  RevenueMonster.pay(
                    outlet_item.outlet.uid,
                    s.id,
                    (outlet_item.price * 100) |> :erlang.trunc(),
                    outlet_item.name
                  )

                sample_res = %{
                  "code" => "SUCCESS",
                  "item" => %{
                    "checkoutId" => "1715311946540550828",
                    "url" =>
                      "https://pg.revenuemonster.my/v3/checkout?checkoutId=1715311946540550828"
                  }
                }

                case res["code"] do
                  "SUCCESS" ->
                    Settings.update_sale(s, %{payment_ref: res["item"]["checkoutId"]})
                    res["item"]["url"]
                end
            end
          else
            _ ->
              nil
          end

        "current_month_outlet_trx_only_days" ->
          Settings.monthly_outlet_trx_only_days(params)

        "current_month_outlet_trx_only_rp" ->
          Settings.monthly_outlet_trx_only_rp(params)

        "yearly_sales_performance" ->
          Settings.yearly_sales_performance("MY", params["organization_id"])

        "get_outlet" ->
          Settings.get_outlet_by_subdomain(params["code"])
          |> BluePotion.sanitize_struct()
          |> Map.take([:address, :name])

        "get_items_by_device" ->
          Settings.list_items_by_device(params["user_id"])
          |> Enum.map(
            &(&1
              |> BluePotion.sanitize_struct()
              |> Map.take([:id, :name, :price, :image_url, :short_name2, :short_name1]))
          )

        "get_contact" ->
          Settings.get_section_by_name("Top Nav Contact")
          |> BluePotion.sanitize_struct()

        "get_pages" ->
          Settings.list_pages()
          |> Enum.map(&(&1 |> BluePotion.sanitize_struct()))

        "get_items" ->
          Settings.list_items_by_subdomain(params["code"])
          |> Enum.map(
            &(&1
              |> BluePotion.sanitize_struct()
              |> Map.take([:id, :name, :price, :image_url, :short_name2, :short_name1]))
          )

        "get_sections" ->
          Settings.list_sections()
          |> Enum.map(&(&1 |> BluePotion.sanitize_struct()))
          |> IO.inspect()

        "get_banners" ->
          Settings.list_slides(true)
          |> Enum.map(&(&1 |> BluePotion.sanitize_struct()))

        "get_product" ->
          Settings.get_product!(params["id"]) |> BluePotion.sanitize_struct()

        "get_products" ->
          products =
            Settings.list_products()
            |> Enum.map(&(&1 |> BluePotion.sanitize_struct()))

          brands = products |> Enum.group_by(& &1.brand) |> Map.keys()

          categories = products |> Enum.group_by(& &1.category) |> Map.keys()
          products = products |> Enum.map(&(&1 |> Map.delete(:brand) |> Map.delete(:category)))
          %{categories: categories, brands: brands, products: products}

        "blog" ->
          b = Settings.get_blog!(params["id"])

          if b.category_id != nil do
            next = Settings.list_blog_next_prev(b.id, b.category_id)
            b |> BluePotion.s_to_map() |> Map.put(:meta, next)
          else
            b |> BluePotion.s_to_map()
          end

        "blogs" ->
          put_ago = fn map ->
            Map.put(map, :ago, map.inserted_at |> BlogEngine.check_time_difference())
          end

          Settings.list_blogs(params)
          |> Enum.map(&(&1 |> BluePotion.sanitize_struct()))
          |> Enum.map(&(&1 |> put_ago.() |> Map.delete(:content)))

        "extend_user" ->
          res = Settings.get_member_by_cookie(params["token"]) |> BluePotion.sanitize_struct()

          if res != nil do
            user = Settings.get_user!(res.user_id)

            token = Settings.member_token(user.id)
            Settings.create_session_user(%{"cookie" => token, "user_id" => user.id})

            res2 =
              user
              |> BluePotion.sanitize_struct()
              |> Map.put(:token, token)

            %{status: "ok", res: res2}
          else
            %{status: "error", reason: "Please contact admin."}
          end

        "get_wifi_logs" ->
          Settings.get_call_counts_with_empty_minutes(params["id"] |> String.to_integer())

        "get_device" ->
          Settings.get_device!(params["id"])
          |> BluePotion.sanitize_struct()

        "get_device_commands" ->
          [
            %{name: "Send 5 reps", value: 5, action: "start"},
            %{name: "Send 10 reps", value: 10, action: "start"},
            %{name: "Send 5 reps (longer 0.4)", value: 5, action: "start", delay: 0.4},
            %{name: "Send 10 reps (longer 0.4)", value: 10, action: "start", delay: 0.4},
            %{name: "Send 5 reps (shorter 0.1)", value: 5, action: "start", delay: 0.1},
            %{name: "Send 10 reps (shorter 0.1)", value: 10, action: "start", delay: 0.1},
            %{name: "Send 5 motor reps", value: 5, action: "motor"}
          ]

        "device_cache_status" ->
          pid = Process.whereis(:device_cache)
          if pid do
            cache_data = Agent.get(pid, fn cache -> cache end)
            %{
              status: "active",
              cached_devices: Map.keys(cache_data),
              cache_size: map_size(cache_data)
            }
          else
            %{status: "not_found", message: "Device cache agent not running"}
          end

        "preload_device_cache" ->
          count = preload_device_cache()
          %{status: "ok", devices_cached: count}

        "clear_device_cache" ->
          clear_device_cache()
          %{status: "ok", message: "Device cache cleared"}

        "translation" ->
          translation = BlogEngine.translation()

          ori = translation |> Enum.map(&(&1 |> Map.get("Ori")))
          eng = translation |> Enum.map(&(&1 |> Map.get("English")))
          thai = translation |> Enum.map(&(&1 |> Map.get("Thailand")))
          chinese = translation |> Enum.map(&(&1 |> Map.get("China")))
          viet = translation |> Enum.map(&(&1 |> Map.get("Vietnam")))

          translation_map =
            case params["lang"] do
              "th" ->
                Enum.zip(ori, thai) |> Enum.into(%{})

              "vn" ->
                Enum.zip(ori, viet) |> Enum.into(%{})

              "cn" ->
                Enum.zip(ori, chinese) |> Enum.into(%{})

              _ ->
                Enum.zip(ori, eng) |> Enum.into(%{})
            end

        "get_role_app_routes" ->
          Settings.get_role!(params["id"]) |> BluePotion.sanitize_struct()

        "get_cookie_user" ->
          Settings.get_cookie_user_by_cookie(params["cookie"]) |> BluePotion.sanitize_struct()

        "announcements" ->
          Settings.list_announcements() |> Enum.map(&(&1 |> BluePotion.sanitize_struct()))

        "gen_inputs" ->
          BluePotion.test_module(params["module"])

        _ ->
          %{status: "ok"}
      end

    append_cache_request = fn conn ->
      if Map.get(conn.params, "scope") in [
           "countries",
           "get_ranks",
           "list_pick_up_point_by_country",
           "list_user_sales_addresses_by_username",
           "translation"
         ] do
        conn
        |> put_resp_header("cache-control", "max-age=900, must-revalidate")
      else
        conn
      end
    end

    with true <- is_map(res),
         true <- Map.get(res, :status) == "error" do
      conn
      |> put_resp_content_type("application/json")
      |> send_resp(500, Jason.encode!(res))
    else
      _ ->
        conn
        |> append_cache_request.()
        |> put_resp_content_type("application/json")
        |> send_resp(200, Jason.encode!(res))
    end
  end

  @doc """
  BlogEngine.Settings.get_sale!(16)
  """
  def payment(conn, params) do
    IO.inspect(params)
    data = Map.get(params, "data")

    order = Map.get(data, "order")
    store = Map.get(data, "store")

    sale =
      BlogEngine.Settings.get_sale!(
        Map.get(order, "id")
        |> String.replace("#{Application.get_env(:blog_engine, :revenue_monster)[:prefix]}", "")
      )
      |> IO.inspect()

    outlet = BlogEngine.Settings.get_outlet_by_uid(store["id"])
    status = Map.get(data, "status") |> IO.inspect()

    case status do
      "SUCCESS" ->
        nil

        uuid = Ecto.UUID.generate()

        device = sale.device
        item = sale.sales_items |> List.first() |> Map.get(:item) |> IO.inspect()

        reps =
          if device.skip_first do
            item.reps - 1
          else
            item.reps
          end

        {delay, reps} =
          if reps == 0 do
            {0.01, 1}
          else
            {item.delay, reps}
          end

        format = device.format

        if device.is_cloridge do
          CloridgeAPI.send_message(reps, device.cloridge_device_uid)
        else
          # BlogEngineWeb.Endpoint.broadcast("user:#{device.name}", "start_pwm", %{
          #   "action" => "start",
          #   "format" => format,
          #   "reps" => reps,
          #   "delay" => delay,
          #   "uuid" => uuid,
          #   "pin" => device.default_io_pin
          # })

          send_device_command(device.name, %{
            "action" => "start",
            "format" => format,
            "reps" => reps,
            "delay" => delay,
            "uuid" => uuid,
            "pin" => device.default_io_pin
          })
        end

        job_content =
          if device.keep_pending_task do
            Jason.encode!(%{
              "action" => "start",
              "reps" => item.reps,
              "delay" => item.delay,
              "uuid" => uuid,
              "pin" => device.default_io_pin
            })
          end

        BlogEngine.Settings.create_device_log(%{
          device_id: device.id,
          uuid: uuid,
          job_content: job_content,
          remarks:
            "sales id:#{sale.id} start #{item.name} with reps: #{item.reps} delay: #{item.delay} on pin #{device.default_io_pin}"
        })
        |> IO.inspect()

        BlogEngine.Settings.update_sale(sale, %{
          payment_webhook: params |> Jason.encode!(),
          status: :complete
        })
        |> IO.inspect()

      _ ->
        nil
    end

    sample = %{
      "data" => %{
        "balanceAmount" => 100,
        "createdAt" => "2024-05-09T08:29:47Z",
        "currencyType" => "MYR",
        "method" => "MAYBANK",
        "order" => %{
          "additionalData" => "world",
          "detail" => "",
          "id" => "7213",
          "title" => "hello"
        },
        "payee" => %{},
        "platform" => "OPEN_API",
        "referenceId" => "MBBQR111111605072728",
        "region" => "MALAYSIA",
        "status" => "SUCCESS",
        "store" => %{
          "addressLine1" => "NO 65,  JALAN SL 9 9D,",
          "addressLine2" => "BANDAR SUNGAI LONG",
          "city" => "Kajang",
          "country" => "Malaysia",
          "countryCode" => "60",
          "createdAt" => "2023-10-10T10:42:55Z",
          "geoLocation" => %{"latitude" => 3.0515925, "longitude" => 101.8087651},
          "id" => "1696934575998530788",
          "imageUrl" => "https://storage.googleapis.com/rm-prod-asset/img/store.png",
          "name" => "ERA HEALTHCARE ENTERPRISE",
          "phoneNumber" => "162056662",
          "postCode" => "43000",
          "state" => "Selangor",
          "status" => "ACTIVE",
          "updatedAt" => "2023-10-16T07:30:01Z"
        },
        "terminalId" => "",
        "transactionAt" => "2024-05-09T08:30:17Z",
        "transactionId" => "17152433871587",
        "type" => "WEB_PAYMENT",
        "updatedAt" => "2024-05-09T08:30:19Z",
        "voucher" => nil
      },
      "eventType" => "PAYMENT_WEB_ONLINE",
      "model" => "billplz"
    }

    json(conn, %{status: "ok"})
  end

  @doc """
     
    BlogEngineWeb.ApiController.ipay88_payment(%Plug.Conn{}, p)
  """

  def razer_payment(conn, params) do
    IO.inspect(params)

    sample = %{
      "ActionType" => "",
      "Amount" => "1.00",
      "AuthCode" => "20240610MBBEMYKL03008551608",
      "BankMID" => "",
      "CCName" => "",
      "CCNo" => "",
      "Currency" => "MYR",
      "ErrDesc" => "",
      "MerchantCode" => "M15137",
      "PaymentId" => "888",
      "RecurringRefno" => "",
      "RefNo" => "TST260",
      "Remark" => "test",
      "S_bankname" => "",
      "S_country" => "",
      "Signature" => "45740fa0c2f04e2525b3008e80cf41c635ae25da34e89f1cb76e3afe52bae960",
      "Status" => "1",
      "SubscriptionNo" => "",
      "TokenId" => "",
      "TranDate" => "2024-06-10",
      "TransId" => "T081892456524",
      "Xfield1" => "",
      "Xfield2" => "",
      "Xfield3" => "",
      "Xfield4" => "",
      "Xfield5" => "",
      "optional" => ""
    }

    fiuu_sample = %{
      "amount" => "3.00",
      "appcode" => "",
      "channel" => "RPP_DuitNowQR",
      "currency" => "RM",
      "domain" => "djtechplt_Dev",
      "error_code" => "",
      "error_desc" => "",
      "extraP" =>
        "{\"DbtrAgt\":\"MBBEMYKL\",\"DbtrAcct_Type\":\"SVGS\",\"TxnType\":\"DOMESTIC\",\"refundability\":\"true\",\"bank_issuer\":\"Maybank Berhad\",\"duitnowqr_indicator\":\"20241225MBBEMYKL030OQR73397985\"}",
      "orderid" => "SO2729",
      "paydate" => "2024-12-25 10:51:03",
      "skey" => "958bdf2c55f373aded4271b10c95082c",
      "status" => "00",
      "tranID" => "2593597375"
    }

    paynow_sample = %{
      "amount" => "1.00",
      "appcode" => "",
      "channel" => "PayNow-Offline_MP",
      "currency" => "SGD",
      "domain" => "djtechplt_Dev",
      "error_code" => "",
      "error_desc" => "",
      "nbcb" => "1",
      "orderid" => "d48a-fc602",
      "paydate" => "2025-01-09 13:47:28",
      "skey" => "d3902c63243c7e911b0c62840b4ba831",
      "status" => "00",
      "tranID" => "2627363301"
    }

    order = params

    sale =
      BlogEngine.Settings.get_sale!(
        Map.get(order, "orderid")
        |> String.replace("#{Application.get_env(:blog_engine, :revenue_monster)[:prefix]}", "")
      )
      |> IO.inspect()

    outlet = BlogEngine.Settings.get_outlet!(sale.outlet_id)
    # status = Map.get(params, "Status") |> IO.inspect()
    status = Map.get(params, "status") |> IO.inspect()

    if sale.status != :complete do
      case status do
        "00" ->
          nil
          uuid = Ecto.UUID.generate()

          device = sale.device

          device = device |> Repo.preload(:executor_board)

          executor_board = device.executor_board

          device =
            if executor_board != nil do
              executor_board
            else
              device
            end

          items = sale.sales_items |> IO.inspect()

          item =
            if items != [] do
              item = items |> List.first() |> Map.get(:item)

              item =
                if item == nil do
                  amount =
                    sale.sales_items
                    |> List.first()
                    |> Map.get(:item_name)
                    |> String.replace("User fill ", "")
                    |> Integer.parse()
                    |> elem(0)

                  reps = (amount / outlet.price_per_minutes) |> :erlang.trunc()

                  %{reps: reps, delay: 0.5, name: "User fill #{amount}"}
                else
                  item
                end
            else
              amount = sale.amount

              reps = (amount / outlet.price_per_minutes) |> :erlang.trunc()

              %{reps: reps, delay: 0.5, name: "User fill #{amount}"}
            end

          reps =
            if device.skip_first do
              item.reps - 1
            else
              item.reps
            end

          {delay, reps} =
            if reps == 0 do
              {0.01, 1}
            else
              {item.delay, reps}
            end

          format = device.format

          if device.is_cloridge do
            CloridgeAPI.send_message(reps, device.cloridge_device_uid)
          else
            send_device_command(device.name, %{
              "action" => "start",
              "format" => format,
              "reps" => reps,
              "delay" => delay,
              "uuid" => uuid,
              "pin" => device.default_io_pin
            })
          end

          job_content =
            if device.keep_pending_task do
              Jason.encode!(%{
                "action" => "start",
                "reps" => item.reps,
                "delay" => item.delay,
                "uuid" => uuid,
                "pin" => device.default_io_pin
              })
            end

          BlogEngine.Settings.create_device_log(%{
            device_id: device.id,
            uuid: uuid,
            job_content: job_content,
            remarks:
              "sales id:#{sale.id} start #{item.name} with reps: #{item.reps} delay: #{item.delay} on pin #{device.default_io_pin}"
          })
          |> IO.inspect()

          BlogEngine.Settings.update_sale(sale, %{
            payment_webhook: params |> Jason.encode!(),
            status: :complete
          })
          |> IO.inspect()

        "1" ->
          nil

          uuid = Ecto.UUID.generate()

          device = sale.device

          device = device |> Repo.preload(:executor_board)

          executor_board = device.executor_board

          device =
            if executor_board != nil do
              executor_board
            else
              device
            end

          items = sale.sales_items |> IO.inspect()

          item =
            if items != [] do
              item = items |> List.first() |> Map.get(:item)

              item =
                if item == nil do
                  amount =
                    sale.sales_items
                    |> List.first()
                    |> Map.get(:item_name)
                    |> String.replace("User fill ", "")
                    |> Integer.parse()
                    |> elem(0)

                  reps = (amount / outlet.price_per_minutes) |> :erlang.trunc()

                  %{reps: reps, delay: 0.5, name: "User fill #{amount}"}
                else
                  item
                end
            else
              amount = sale.amount

              reps = (amount / outlet.price_per_minutes) |> :erlang.trunc()

              %{reps: reps, delay: 0.5, name: "User fill #{amount}"}
            end

          reps =
            if device.skip_first do
              item.reps - 1
            else
              item.reps
            end

          {delay, reps} =
            if reps == 0 do
              {0.01, 1}
            else
              {item.delay, reps}
            end

          format = device.format

          if device.is_cloridge do
            CloridgeAPI.send_message(reps, device.cloridge_device_uid)
          else
            # BlogEngineWeb.Endpoint.broadcast("user:#{device.name}", "start_pwm", %{
            #   "action" => "start",
            #   "format" => format,
            #   "reps" => reps,
            #   "delay" => delay,
            #   "uuid" => uuid,
            #   "pin" => device.default_io_pin
            # })
            send_device_command(device.name, %{
              "action" => "start",
              "format" => format,
              "reps" => reps,
              "delay" => delay,
              "uuid" => uuid,
              "pin" => device.default_io_pin
            })
          end

          job_content =
            if device.keep_pending_task do
              Jason.encode!(%{
                "action" => "start",
                "reps" => item.reps,
                "delay" => item.delay,
                "uuid" => uuid,
                "pin" => device.default_io_pin
              })
            end

          BlogEngine.Settings.create_device_log(%{
            device_id: device.id,
            uuid: uuid,
            job_content: job_content,
            remarks:
              "sales id:#{sale.id} start #{item.name} with reps: #{item.reps} delay: #{item.delay} on pin #{device.default_io_pin}"
          })
          |> IO.inspect()

          BlogEngine.Settings.update_sale(sale, %{
            payment_webhook: params |> Jason.encode!(),
            status: :complete
          })
          |> IO.inspect()

        _ ->
          nil
      end
    end

    json(conn, %{status: "ok"})
  end

  def ipay88_payment(conn, params) do
    IO.inspect(params)

    sample = %{
      "ActionType" => "",
      "Amount" => "1.00",
      "AuthCode" => "20240610MBBEMYKL03008551608",
      "BankMID" => "",
      "CCName" => "",
      "CCNo" => "",
      "Currency" => "MYR",
      "ErrDesc" => "",
      "MerchantCode" => "M15137",
      "PaymentId" => "888",
      "RecurringRefno" => "",
      "RefNo" => "TST260",
      "Remark" => "test",
      "S_bankname" => "",
      "S_country" => "",
      "Signature" => "45740fa0c2f04e2525b3008e80cf41c635ae25da34e89f1cb76e3afe52bae960",
      "Status" => "1",
      "SubscriptionNo" => "",
      "TokenId" => "",
      "TranDate" => "2024-06-10",
      "TransId" => "T081892456524",
      "Xfield1" => "",
      "Xfield2" => "",
      "Xfield3" => "",
      "Xfield4" => "",
      "Xfield5" => "",
      "optional" => ""
    }

    fiuu_sample = %{
      "amount" => "3.00",
      "appcode" => "",
      "channel" => "RPP_DuitNowQR",
      "currency" => "RM",
      "domain" => "djtechplt_Dev",
      "error_code" => "",
      "error_desc" => "",
      "extraP" =>
        "{\"DbtrAgt\":\"MBBEMYKL\",\"DbtrAcct_Type\":\"SVGS\",\"TxnType\":\"DOMESTIC\",\"refundability\":\"true\",\"bank_issuer\":\"Maybank Berhad\",\"duitnowqr_indicator\":\"20241225MBBEMYKL030OQR73397985\"}",
      "orderid" => "SO2729",
      "paydate" => "2024-12-25 10:51:03",
      "skey" => "958bdf2c55f373aded4271b10c95082c",
      "status" => "00",
      "tranID" => "2593597375"
    }

    order = params

    sale =
      BlogEngine.Settings.get_sale!(
        Map.get(order, "orderid")
        |> String.replace("#{Application.get_env(:blog_engine, :revenue_monster)[:prefix]}", "")
      )
      |> IO.inspect()

    outlet = BlogEngine.Settings.get_outlet!(sale.outlet_id)
    # status = Map.get(params, "Status") |> IO.inspect()
    status = Map.get(params, "status") |> IO.inspect()

    if sale.status != :complete do
      case status do
        "00" ->
          nil
          uuid = Ecto.UUID.generate()

          device = sale.device

          device = device |> Repo.preload(:executor_board)

          executor_board = device.executor_board

          device =
            if executor_board != nil do
              executor_board
            else
              device
            end

          items = sale.sales_items |> IO.inspect()

          item =
            if items != [] do
              item = items |> List.first() |> Map.get(:item)

              item =
                if item == nil do
                  amount =
                    sale.sales_items
                    |> List.first()
                    |> Map.get(:item_name)
                    |> String.replace("User fill ", "")
                    |> Integer.parse()
                    |> elem(0)

                  reps = (amount / outlet.price_per_minutes) |> :erlang.trunc()

                  %{reps: reps, delay: 0.5, name: "User fill #{amount}"}
                else
                  item
                end
            else
              amount = sale.amount

              reps = (amount / outlet.price_per_minutes) |> :erlang.trunc()

              %{reps: reps, delay: 0.5, name: "User fill #{amount}"}
            end

          reps =
            if device.skip_first do
              item.reps - 1
            else
              item.reps
            end

          {delay, reps} =
            if reps == 0 do
              {0.01, 1}
            else
              {item.delay, reps}
            end

          format = device.format

          if device.is_cloridge do
            CloridgeAPI.send_message(reps, device.cloridge_device_uid)
          else
            # BlogEngineWeb.Endpoint.broadcast("user:#{device.name}", "start_pwm", %{
            #   "action" => "start",
            #   "format" => format,
            #   "reps" => reps,
            #   "delay" => delay,
            #   "uuid" => uuid,
            #   "pin" => device.default_io_pin
            # })

            send_device_command(device.name, %{
              "action" => "start",
              "format" => format,
              "reps" => reps,
              "delay" => delay,
              "uuid" => uuid,
              "pin" => device.default_io_pin
            })
          end

          job_content =
            if device.keep_pending_task do
              Jason.encode!(%{
                "action" => "start",
                "reps" => item.reps,
                "delay" => item.delay,
                "uuid" => uuid,
                "pin" => device.default_io_pin
              })
            end

          BlogEngine.Settings.create_device_log(%{
            device_id: device.id,
            uuid: uuid,
            job_content: job_content,
            remarks:
              "sales id:#{sale.id} start #{item.name} with reps: #{item.reps} delay: #{item.delay} on pin #{device.default_io_pin}"
          })
          |> IO.inspect()

          BlogEngine.Settings.update_sale(sale, %{
            payment_webhook: params |> Jason.encode!(),
            status: :complete
          })
          |> IO.inspect()

        "1" ->
          nil

          uuid = Ecto.UUID.generate()

          device = sale.device

          device = device |> Repo.preload(:executor_board)

          executor_board = device.executor_board

          device =
            if executor_board != nil do
              executor_board
            else
              device
            end

          items = sale.sales_items |> IO.inspect()

          item =
            if items != [] do
              item = items |> List.first() |> Map.get(:item)

              item =
                if item == nil do
                  amount =
                    sale.sales_items
                    |> List.first()
                    |> Map.get(:item_name)
                    |> String.replace("User fill ", "")
                    |> Integer.parse()
                    |> elem(0)

                  reps = (amount / outlet.price_per_minutes) |> :erlang.trunc()

                  %{reps: reps, delay: 0.5, name: "User fill #{amount}"}
                else
                  item
                end
            else
              amount = sale.amount

              reps = (amount / outlet.price_per_minutes) |> :erlang.trunc()

              %{reps: reps, delay: 0.5, name: "User fill #{amount}"}
            end

          reps =
            if device.skip_first do
              item.reps - 1
            else
              item.reps
            end

          {delay, reps} =
            if reps == 0 do
              {0.01, 1}
            else
              {item.delay, reps}
            end

          format = device.format

          if device.is_cloridge do
            CloridgeAPI.send_message(reps, device.cloridge_device_uid)
          else
            send_device_command(device.name, %{
              "action" => "start",
              "format" => format,
              "reps" => reps,
              "delay" => delay,
              "uuid" => uuid,
              "pin" => device.default_io_pin
            })
          end

          job_content =
            if device.keep_pending_task do
              Jason.encode!(%{
                "action" => "start",
                "reps" => item.reps,
                "delay" => item.delay,
                "uuid" => uuid,
                "pin" => device.default_io_pin
              })
            end

          BlogEngine.Settings.create_device_log(%{
            device_id: device.id,
            uuid: uuid,
            job_content: job_content,
            remarks:
              "sales id:#{sale.id} start #{item.name} with reps: #{item.reps} delay: #{item.delay} on pin #{device.default_io_pin}"
          })
          |> IO.inspect()

          BlogEngine.Settings.update_sale(sale, %{
            payment_webhook: params |> Jason.encode!(),
            status: :complete
          })
          |> IO.inspect()

        _ ->
          nil
      end
    end

    json(conn, %{status: "ok"})
  end

  def another_call(params) do
    Process.sleep(2000)

    case HTTPoison.post(
           params["callback_url"],
           params |> Jason.encode!(),
           [{"Content-Type", "application/json"}]
         )
         |> IO.inspect(label: "callback ation") do
      {:ok,
       %HTTPoison.Response{
         body: body
       } = _res} ->
        body

      _ ->
        nil
    end
  end

  def post(conn, params) do
    res =
      case params["scope"] do
        "simulate_sales" ->
          Elixir.Task.start(__MODULE__, :another_call, [params])
          %{status: "ok", res: params}

        "user_fcm_token" ->
          check_staff = params["user_token"] |> BlogEngine.Settings.get_cookie_user_by_cookie()

          if check_staff != nil do
            # this is a Staff struct
            Settings.create_messaging_device(%{
              "staff_id" => check_staff.user.id,
              "uuid" => params["token"]
            })
          end

          %{status: "ok"}

        "delete_all_device_log" ->
          Settings.delete_all_device_log(params["device_id"])
          %{status: "ok"}

        "gen_static_qr" ->
          device = Settings.get_device_by_name(params["name"]) |> IO.inspect()

          # sample: Razer.staticqr("d48a-fc602e74", "Duitnow Fiuu", "djtechplt_Dev", "e37344c535a8d12000294306994251a3", "SGD")

          if device != nil do
            res =
              Razer.staticqr(
                device.short_name,
                device.outlet.name,
                device.outlet.mcode,
                device.outlet.mkey,
                device.outlet.currency
              )

            Settings.update_device(device, %{"qr_code_data" => res["qrcode_data"]})

            res
          else
            %{status: "ok"}
          end

        "checkout_by_amount" ->
          sample = %{
            "item_id" => 2,
            "scope" => "checkout",
            "user_id" => "00000000-0000-0000-d83a-dda0064d"
          }

          # outlet_item = Settings.get_item!(params["item_id"]) |> BluePotion.sanitize_struct()
          device = Settings.get_device_by_name(params["user_id"])
          amount = params["amount"]

          {:ok, s} =
            Settings.create_sale(%{
              sales_date: Date.utc_today(),
              outlet_id: device.outlet.id,
              device_id: device.id,
              organization_id: device.organization_id,
              amount: amount,
              status: :pending_payment,
              uid: Ecto.UUID.generate()
            })

          Settings.create_sales_item(%{
            item_id: nil,
            sales_id: s.id,
            item_amount: amount,
            item_name: "User fill #{amount}",
            qty: 1,
            subtotal: amount * 1
          })

          final_data =
            case device.outlet.payment_gateway do
              "ipay88" ->
                response =
                  Ipay88.send_soap_request(
                    device.outlet.mkey,
                    device.outlet.mcode,
                    amount,
                    "#{Application.get_env(:blog_engine, :revenue_monster)[:prefix]}#{s.id}",
                    "MYR",
                    "User fill #{amount}",
                    device.id,
                    "yithanglee",
                    "yithanglee@gmail.com",
                    "0122664254"
                  )

                response

              _ ->
                res =
                  RevenueMonster.pay(
                    device.outlet.uid,
                    "#{Application.get_env(:blog_engine, :revenue_monster)[:prefix]}#{s.id}",
                    (amount * 100) |> :erlang.trunc(),
                    "User fill #{amount}"
                  )

                final_data =
                  case res["code"] do
                    "SUCCESS" ->
                      checkout_id = Map.get(res, "item") |> Map.get("checkoutId")

                      get_qr(s, checkout_id)

                    _ ->
                      "test.bmp"
                  end
            end

          %{name: final_data}

        "checkout" ->
          sample = %{
            "item_id" => 2,
            "scope" => "checkout",
            "user_id" => "00000000-0000-0000-d83a-dda0064d"
          }

          outlet_item = Settings.get_item!(params["item_id"]) |> BluePotion.sanitize_struct()
          device = Settings.get_device_by_name(params["user_id"])

          {:ok, s} =
            Settings.create_sale(%{
              sales_date: Date.utc_today(),
              outlet_id: outlet_item.outlet.id,
              device_id: device.id,
              organization_id: device.organization_id,
              amount: outlet_item.price,
              status: :pending_payment,
              uid: Ecto.UUID.generate()
            })

          Settings.create_sales_item(%{
            item_id: outlet_item.id,
            sales_id: s.id,
            item_amount: outlet_item.price,
            item_name: outlet_item.name,
            qty: 1,
            subtotal: outlet_item.price * 1
          })

          res =
            RevenueMonster.pay(
              outlet_item.outlet.uid,
              "#{Application.get_env(:blog_engine, :revenue_monster)[:prefix]}#{s.id}",
              (outlet_item.price * 100) |> :erlang.trunc(),
              outlet_item.name
            )

          final_data =
            case res["code"] do
              "SUCCESS" ->
                checkout_id = Map.get(res, "item") |> Map.get("checkoutId")

                get_qr(s, checkout_id)

              _ ->
                "test.bmp"
            end

          %{name: final_data}

        "start_pwm" ->
          # BlogEngineWeb.Endpoint.broadcast("user:00000000-0000-0000-d83a-dd9f81e5", "ping", %{"action" => "start", "reps" => 10})
          uuid = Ecto.UUID.generate()

          device = BlogEngine.Settings.get_device_by_name(params["name"])

          params =
            case params["value"] do
              c when is_binary(c) ->
                rep = Integer.parse(c) |> elem(0)

                Map.put(params, "value", rep)

              _ ->
                params
            end

          IO.inspect(params)

          reps =
            if device.skip_first do
              params["value"] - 1
            else
              params["value"]
            end

          {delay, reps} =
            if reps == 0 do
              {0.01, 1}
            else
              {params["delay"], reps}
            end

          format = params["format"] || "pwm"

          if device.is_cloridge do
            CloridgeAPI.send_message(reps, device.cloridge_device_uid)
          else
            # BlogEngineWeb.Endpoint.broadcast("user:#{params["name"]}", "start_pwm", %{
            #   "action" => params["action"],
            #   "format" => format,
            #   "reps" => reps,
            #   "delay" => delay,
            #   "uuid" => uuid,
            #   "pin" => device.default_io_pin
            # })
            send_device_command(params["name"], %{
              "action" => params["action"],
              "format" => format,
              "reps" => reps,
              "delay" => delay,
              "uuid" => uuid,
              "pin" => device.default_io_pin
            })
          end

          job_content =
            if device.keep_pending_task do
              Jason.encode!(%{
                "action" => params["action"],
                "reps" => params["value"],
                "delay" => params["delay"],
                "uuid" => uuid,
                "pin" => device.default_io_pin
              })
            end

          BlogEngine.Settings.create_device_log(%{
            device_id: device.id,
            uuid: uuid,
            job_content: job_content,
            remarks:
              "manual start #{format} #{params["item_name"]} on pin #{device.default_io_pin}"
          })

          %{status: "ok"}

        "sync_menu" ->
          params["_json"] |> Settings.populate_menus() |> IO.inspect()
          %{status: "ok"}

        "admin_menus" ->
          params["list"] |> Settings.update_admin_menus()

          %{status: "ok"}

        "sign_in" ->
          # admin login
          res = Settings.check_staff_password(params)

          case res do
            {true, user} ->
              token =
                Phoenix.Token.sign(
                  BlogEngineWeb.Endpoint,
                  "admin_signature",
                  params["username"]
                )

              Settings.create_session_user(%{"cookie" => token, "user_id" => user.id})

              %{
                id: user.id,
                status: "ok",
                res: token,
                user: user |> BluePotion.sanitize_struct(),
                role_app_routes:
                  user.role.app_routes |> Enum.map(&(&1 |> BluePotion.sanitize_struct()))
              }

            {false, _res} ->
              %{status: "error", reason: "Invalid credentials"}
          end

        "override" ->
          auth = Settings.override_user(params["user"]) |> IO.inspect()

          case auth do
            {:ok, user} ->
              token = Settings.member_token(user.id)
              Settings.create_session_user(%{"cookie" => token, "user_id" => user.id})

              %{
                status: "ok",
                res:
                  user
                  |> BluePotion.sanitize_struct()
                  |> Map.put(:token, token)
              }

            _ ->
              %{status: "error"}
          end

        "login" ->
          auth = Settings.auth_user(params["user"]) |> IO.inspect()

          case auth do
            {:ok, user} ->
              token = Settings.member_token(user.id)
              Settings.create_session_user(%{"cookie" => token, "user_id" => user.id})

              %{
                status: "ok",
                res:
                  user
                  |> BluePotion.sanitize_struct()
                  |> Map.put(:token, token)
              }

            _ ->
              %{status: "error"}
          end

        _ ->
          %{status: "ok"}
      end

    append_session = fn conn ->
      # conn |> put_session(:test_session, %{id: 1, role: "tester"})
      conn
    end

    conn
    |> append_session.()
    |> json(res)
  end

  def print_pdf(conn, params) do
    check = File.exists?(File.cwd!() <> "/media")
    filename = params["filename"]

    path =
      if check do
        File.cwd!() <> "/media"
      else
        File.mkdir(File.cwd!() <> "/media")
        File.cwd!() <> "/media"
      end

    server_url = Application.get_env(:blog_engine, :endpoint)[:url]
    IO.inspect(server_url)

    {:ok, html} = File.read("#{path}/#{filename}.html")

    html =
      html
      |> String.replace("\"/images", "\"#{server_url}/images")
      |> String.replace("\'/images", "\'#{server_url}/images")

    host = conn.req_headers |> Enum.into(%{}) |> Map.get("host")

    css = """

    <link rel="stylesheet" type="text/css" href="#{server_url}/sticky/styles/bootstrap.css">
    <link rel="stylesheet" type="text/css" href="#{server_url}/sticky/styles/style.css">
    """

    pdf_params = %{
      "html" => "<!DOCTYPE html><html><head>#{css}</head><body>#{html}</body></html>"
    }

    # pdf_params = %{"html" => html}
    IO.inspect(pdf_params)
    IO.puts(pdf_params["html"])

    pdf_binary =
      PdfGenerator.generate_binary!(
        pdf_params["html"],
        size: "A4",
        shell_params: [
          "--page-width",
          "100cm",
          "--margin-left",
          "5",
          "--margin-right",
          "5",
          "--margin-top",
          "5",
          "--margin-bottom",
          "5",
          "--encoding",
          "utf-8",
          "--orientation",
          "Portrait"
        ],
        delete_temporary: true
      )

    conn
    |> put_resp_content_type("application/pdf")
    |> put_resp_header(
      "content-disposition",
      "attachment; filename=\"#{params["title"]}.pdf\""
    )
    |> send_resp(200, pdf_binary)
  end

  def append_params(params) do
    password = Map.get(params, "password")

    params =
      if password != nil do
        crypted_password = :crypto.hash(:sha512, password) |> Base.encode16() |> String.downcase()

        params
        |> Map.put(
          "crypted_password",
          crypted_password
        )
      else
        params
      end

    IO.inspect("appended")
    IO.inspect(params)

    params
  end

  def form_submission(conn, params) do
    model = Map.get(params, "model")
    params = Map.delete(params, "model")

    upcase? = fn x -> x == String.upcase(x) end

    sanitized_model =
      model
      |> String.split("")
      |> Enum.reject(&(&1 == ""))
      |> Enum.map(
        &if upcase?.(&1), do: String.replace(&1, &1, "_#{String.downcase(&1)}"), else: &1
      )
      |> Enum.join("")
      |> String.split("")
      |> Enum.reject(&(&1 == ""))
      |> List.pop_at(0)
      |> elem(1)
      |> Enum.join()

    IO.inspect(params)
    json = %{}
    config = Application.get_env(:blue_potion, :contexts)

    mods =
      if config == nil do
        ["Settings", "Secretary"]
      else
        config
      end

    struct =
      for mod <- mods do
        Module.concat([Application.get_env(:blue_potion, :otp_app), mod, model])
      end
      |> Enum.filter(&Code.ensure_compiled?(&1))
      |> List.first()

    IO.inspect(struct)

    mod =
      struct
      |> Module.split()
      |> Enum.take(2)
      |> Module.concat()

    IO.inspect(mod)

    booleans =
      BluePotion.test_module(model)
      |> Map.to_list()
      |> Enum.filter(&(elem(&1, 1) == :boolean))
      |> Enum.map(&(elem(&1, 0) |> Atom.to_string()))

    dynamic_code =
      if Map.get(params, model) |> Map.get("id") != "0" do
        """
        struct = #{mod}.get_#{sanitized_model}!(params["id"])
        #{mod}.update_#{sanitized_model}(struct, params)
        """
      else
        """
        #{mod}.create_#{sanitized_model}(params)
        """
      end

    p = Map.get(params, model)

    p =
      case model do
        c when c in ["CorporateAccount"] ->
          case p["id"] |> Integer.parse() do
            :error ->
              {:ok, map} =
                Phoenix.Token.verify(
                  BlogEngineWeb.Endpoint,
                  "corporate_account_signature",
                  p["id"]
                )

              p = Map.put(p, "id", map.id)

              append_params(p)

            _ ->
              append_params(p)
          end

        # c when c in ["Blog", "Shop", "Announcement"] ->
        #   case p["corporate_account_id"] |> Integer.parse() do
        #     :error ->
        #       {:ok, map} =
        #         Phoenix.Token.verify(
        #           BlogEngineWeb.Endpoint,
        #           "corporate_account_signature",
        #           p["corporate_account_id"]
        #         )

        #       p = Map.put(p, "corporate_account_id", map.id)

        #       append_params(p)

        #     _ ->
        #       append_params(p)
        #   end

        "CorporateTopup" ->
          cond do
            p["corporate_account_id"] != nil ->
              if p["corporate_account_id"] |> Integer.parse() == :error do
                {:ok, map} =
                  Phoenix.Token.verify(
                    BlogEngineWeb.Endpoint,
                    "corporate_account_signature",
                    p["corporate_account_id"]
                  )

                p = Map.put(p, "corporate_account_id", map.id)

                append_params(p)
              else
                p
              end

            p["id"] != "" ->
              p
          end

        "User" ->
          case p["id"] |> Integer.parse() do
            :error ->
              {:ok, map} = Phoenix.Token.verify(BlogEngineWeb.Endpoint, "signature", p["id"])
              Map.put(p, "id", map.id)

            _ ->
              p
          end

        _ ->
          p
      end

    p = booleans |> Enum.reduce(p, &BlogEngine.Settings.append_bool_key(&2, &1))
    {result, _values} = Code.eval_string(dynamic_code, params: p |> BlogEngine.upload_file())

    IO.inspect(result)

    case result do
      {:ok, item} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, Jason.encode!(BluePotion.sanitize_struct(item)))

      {:error, %Ecto.Changeset{} = changeset} ->
        errors = changeset.errors |> Keyword.keys()

        {reason, message} = changeset.errors |> hd()
        {proper_message, message_list} = message
        final_reason = Atom.to_string(reason) <> " " <> proper_message

        conn
        |> put_resp_content_type("application/json")
        |> send_resp(500, Jason.encode!(%{status: final_reason}))
    end
  end

  def datatable(conn, params) do
    decode_token = fn params ->
      customer_id = Map.get(params, "user_id")

      params =
        if customer_id != nil do
          params
          |> Map.put(
            "user_id",
            BlogEngine.Settings.decode_token(customer_id)
          )
        else
          params
        end
    end

    model = Map.get(params, "model")
    preloads = Map.get(params, "preloads")
    additional_search_queries = Map.get(params, "additional_search_queries")
    additional_join_statements = Map.get(params, "additional_join_statements") |> IO.inspect()
    params = Map.delete(params, "model") |> Map.delete("preloads") |> Map.delete("host")

    search_queries =
      for key <- params["columns"] |> Map.keys() do
        val = params["columns"][key]["search"]["value"]

        if val != "" do
          {String.to_atom(params["columns"][key]["data"]), val}
        end
      end
      |> Enum.reject(fn x -> x == nil end)
      |> Enum.reject(fn x -> elem(x, 1) == nil end)

    additional_search_params =
      params
      |> Map.drop([
        "_",
        "rowFn",
        "pageLength",
        "additional_join_statements",
        "additional_search_queries",
        "additional_order_statements",
        "columns",
        "draw",
        "foo",
        "length",
        "order",
        "search",
        "start"
      ])

    asp = additional_search_params |> Map.keys()

    search_queries2 =
      for asp_child <- asp do
        {String.to_atom(asp_child), additional_search_params |> Map.get(asp_child)}
      end

    addon_search =
      if search_queries2 != [] do
        for {key, val} = sq2 <- search_queries2 do
          cond do
            Integer.parse(val) != :error ->
              {int, _suffix} = Integer.parse(val)

              """
                a.#{Atom.to_string(key)}==#{int} 
              """

            val == "null" ->
              """
                is_nil(a.#{Atom.to_string(key)}) 
              """

            Atom.to_string(key) |> String.contains?("_id") ->
              """
                a.#{Atom.to_string(key)}==#{val} 
              """

            val == "true" || val == "false" ->
              """
                a.#{Atom.to_string(key)}==#{val} 
              """

            true ->
              """
                a.#{Atom.to_string(key)}=="#{val}"
              """
          end
        end
        |> Enum.join(" and ")
      else
        ""
      end
      |> IO.inspect()

    params =
      decode_token.(params)
      |> IO.inspect()

    additional_join_statements =
      if additional_join_statements == nil do
        ""
      else
        joins = additional_join_statements |> Poison.decode!() |> IO.inspect()

        for join <- joins do
          key = Map.keys(join) |> List.first()
          value = join |> Map.get(key)

          config = Application.get_env(:blue_potion, :contexts)

          mods =
            if config == nil do
              ["Settings", "Secretary"]
            else
              config
            end

          struct =
            for mod <- mods do
              Module.concat([Application.get_env(:blue_potion, :otp_app), mod, key])
            end
            |> Enum.filter(&(elem(Code.ensure_compiled(&1), 0) == :module))
            |> List.first()

          "|> join(:left, [a], b in assoc(a, :#{key}))"
        end
        |> Enum.join("")
        |> IO.inspect()
      end

    Logger.info("additional_join_statements - #{additional_join_statements}")
    additional_order_statements = Map.get(params, "additional_order_statements", [])

    jkeys =
      if params["additional_join_statements"] != nil do
        params["additional_join_statements"]
        |> Jason.decode!()
        |> Enum.map(&(&1 |> Map.keys() |> List.first()))
        |> IO.inspect()
      else
        []
      end

    additional_order_statements =
      if additional_order_statements != [] do
        for item <- additional_order_statements |> Jason.decode!() do
          sample = %{"column" => "code", "dir" => "desc"}
          IO.inspect(item)

          if item["column"] |> String.contains?(".") do
            if jkeys != [] do
              [key, col2] = String.split(item["column"], ".") |> IO.inspect()
              dir = Map.get(item, "dir")
              col = Map.get(item, "column")

              atoms = ["b", "c", "d"]
              index = Enum.find_index(jkeys, &(&1 == key))

              "#{dir}: #{atoms |> Enum.at(index)}.#{col2}"
            else
              nil
            end
          else
            # "|> sort_by([a,b,c,d], asc: a.#{})"

            dir = Map.get(item, "dir")
            col = Map.get(item, "column")
            "#{dir}: a.#{col}"
          end
        end
        |> Enum.reject(&(&1 == nil))
      else
        []
      end

    post_additional_order_statements =
      if additional_order_statements != [] do
        """
        |> order_by([a,b,c,d], #{additional_order_statements |> Enum.join(",")})
        """
      else
        ""
      end

    Logger.info("additional_order_statements -")
    IO.inspect(post_additional_order_statements)

    additional_search_queries =
      if additional_search_queries == nil do
        if addon_search != "" do
          """
          |> where([a,b,c,d], #{addon_search})
          """
        else
          ""
        end
      else
        columns = additional_search_queries |> String.split(",")

        for {item, index} <- columns |> Enum.with_index() do
          cond do
            item |> String.contains?("!=") ->
              [i, val] = item |> String.split("!=")

              """
              |> where([a,b,c,d], a.#{i} != #{val}) 
              """

            item |> String.contains?("_id^") ->
              item = item |> String.replace("^", "")
              [_prefix, i] = item |> String.split(".")
              ss = params["search"]["value"]

              if ss != "" do
                case Integer.parse(ss) do
                  {ss, _} ->
                    """
                    |> where([a,b,c,d], a.#{i} == ^"#{ss}") 
                    """

                  _ ->
                    """
                    |> where([a,b,c,d], a.#{i} == ^"#{ss}") 
                    """
                end
              end

            item |> String.contains?("^") ->
              item = item |> String.replace("^", "")
              [prefix, i] = item |> String.split(".")
              ss = params["search"]["value"]

              if ss != "" do
                """
                |> where([a,b,c,d],  ilike(#{prefix}.#{i}, ^"%#{ss}%") ) 
                """
              end

            true ->
              ss = params["search"]["value"]
              items = String.split(item, "|")
              ori_addon_search = addon_search

              addon_search =
                if addon_search != "" do
                  " and #{addon_search}"
                else
                  ""
                end

              subquery =
                for i <- items do
                  if i |> String.contains?(".") do
                    [prefix, i] = i |> String.split(".")
                    # if possible, here need to add back the previous and statements
                    [i, value] =
                      if i |> String.contains?("=") do
                        [i, value] = String.split(i, "=")
                      else
                        [i, ""]
                      end

                    ss =
                      if value != "" do
                        value
                      else
                        ss
                      end

                    check_id = fn tuple ->
                      if tuple |> is_tuple do
                        {prefix, i, ss} = tuple

                        if i |> String.contains?("_id") do
                          case Integer.parse(ss) do
                            {ss, _val} ->
                              """
                              #{prefix}.#{i} == ^#{ss} #{addon_search}
                              """

                            _ ->
                              """
                              ilike(a.#{i}, ^"%#{ss}%")  #{addon_search}
                              """
                          end
                        else
                          with true <-
                                 i |> String.contains?("id") || i in ["year", "month", "day"],
                               false <- i |> String.contains?("uuid"),
                               false <- i |> String.contains?("paid"),
                               false <- i |> String.contains?("is_"),
                               true <- ss != nil do
                            case Integer.parse(ss) |> IO.inspect() do
                              {ss, _val} ->
                                """
                                #{prefix}.#{i} == ^#{ss}  #{addon_search}
                                """

                              _ ->
                                """
                                ilike(a.#{i}, ^"%#{ss}%")  #{addon_search}
                                """
                            end
                          else
                            _ ->
                              tuple
                          end
                        end
                      else
                        tuple
                      end
                    end

                    check_date = fn tuple ->
                      if tuple |> is_tuple do
                        {prefix, i, ss} = tuple

                        if i == "date" do
                          """
                          #{prefix}.#{i} == ^"#{ss}"  #{addon_search}
                          """
                        else
                          tuple
                        end
                      else
                        tuple
                      end
                    end

                    check_bool = fn tuple ->
                      if tuple |> is_tuple do
                        {prefix, i, ss} = tuple

                        if ss == "true" || ss == "false" do
                          """
                          #{prefix}.#{i} == ^#{ss}  #{addon_search}
                          """
                        else
                          if ss == nil do
                            """
                            #{ori_addon_search}
                            """
                          else
                            """
                            ilike(#{prefix}.#{i}, ^"%#{ss}%")  #{addon_search}
                            """
                          end
                        end
                      else
                        tuple
                      end
                    end

                    check_id.({prefix, i, ss})
                    |> check_date.()
                    |> check_bool.()
                  else
                    [i, value] =
                      if i |> String.contains?("=") do
                        [i, value] = String.split(i, "=")
                      else
                        [i, ""]
                      end

                    ss =
                      if value != "" do
                        value
                      else
                        ss
                      end

                    unless i |> String.contains?("_id") do
                      if ss == "true" || ss == "false" do
                        """
                        a.#{i} == ^#{ss}  #{addon_search}
                        """
                      else
                        """
                        ilike(a.#{i}, ^"%#{ss}%")  #{addon_search}
                        """
                      end
                    else
                      case Integer.parse(ss) do
                        {ss, _val} ->
                          """
                          a.#{i} == ^#{ss}  #{addon_search}
                          """

                        _ ->
                          if ss == "true" || ss == "false" do
                            """
                            a.#{i} == ^#{ss}  #{addon_search}
                            """
                          else
                            """
                            ilike(a.#{i}, ^"%#{ss}%")  #{addon_search}
                            """
                          end
                      end
                    end
                  end
                end
                |> Enum.reject(&(&1 == nil))
                |> Enum.reject(&(&1 == ""))
                |> Enum.join(" and ")
                |> IO.inspect()

              with true <- subquery != "",
                   true <- ss != nil do
                # consider append existing search queries..

                """
                |> or_where([a,b,c,d], #{subquery} )
                """
              else
                _ ->
                  with true <- subquery != "",
                       true <- subquery != "\n",
                       false <- subquery |> String.contains?("and \n") do
                    """
                    |> or_where([a,b,c,d], #{subquery} )
                    """
                  else
                    _ ->
                      nil
                  end
              end
          end
        end
        |> Enum.reject(&(&1 == nil))
        |> Enum.join("")
      end
      |> IO.inspect()

    Enum.map([1, 2, 4], fn x -> x end)

    preloads =
      if preloads == nil do
        preloads = []
      else
        IO.inspect("preload ")

        preloads
        |> Poison.decode!()
        |> Enum.map(&(&1 |> BluePotion.convert_to_atom()))
      end
      |> List.flatten()

    IO.inspect(preloads)

    json =
      BluePotion.post_process_datatable(
        params,
        Module.concat(["BlogEngine", "Settings", model]),
        additional_join_statements,
        additional_search_queries,
        preloads,
        post_additional_order_statements
      )

    %{data: data, draw: _draw, recordsFiltered: _recordsFiltered, recordsTotal: _recordsTotal} =
      json

    sanitize_pw = fn data ->
      if model == "Sale" do
        data
        |> Enum.map(fn x ->
          x
          |> IO.inspect()
          |> Map.put(
            :registration_details,
            x.registration_details
            |> Jason.decode!()
            |> Kernel.get_and_update_in(["user", "password"], &{&1, ""})
            |> elem(1)
            |> Jason.encode!()
          )
        end)
      else
        data
      end
    end

    json = Map.put(json, :data, data)

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(json))
  end

  def delete_data(conn, params) do
    model = Map.get(params, "model")
    params = Map.delete(params, "model")

    upcase? = fn x -> x == String.upcase(x) end

    sanitized_model =
      model
      |> String.split("")
      |> Enum.reject(&(&1 == ""))
      |> Enum.map(
        &if upcase?.(&1), do: String.replace(&1, &1, "_#{String.downcase(&1)}"), else: &1
      )
      |> Enum.join("")
      |> String.split("")
      |> Enum.reject(&(&1 == ""))
      |> List.pop_at(0)
      |> elem(1)
      |> Enum.join()

    IO.inspect(params)
    json = %{}

    config = Application.get_env(:blue_potion, :contexts)

    mods =
      if config == nil do
        ["Settings", "Secretary"]
      else
        config
      end

    struct =
      for mod <- mods do
        Module.concat([Application.get_env(:blue_potion, :otp_app), mod, model])
      end
      |> Enum.filter(&({:error, :nofile} != Code.ensure_compiled(&1)))
      |> List.first()

    IO.inspect(struct)

    mod =
      struct
      |> Module.split()
      |> Enum.take(2)
      |> Module.concat()

    IO.inspect(mod)

    dynamic_code = """
    struct = #{mod}.get_#{sanitized_model}!(params["id"])
    #{mod}.delete_#{sanitized_model}(struct)
    """

    {result, _values} = Code.eval_string(dynamic_code, params: params)

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(%{status: "already deleted"}))
  end

  def get_qr(s, checkout_id) do
    res2 = RevenueMonster.direct_checkout(checkout_id)

    sample_res2 = %{
      "code" => "SUCCESS",
      "item" => %{
        "qrcode" => %{
          "base64Image" =>
            "iVBORw0KGgoAAAANSUhEUgAAAQkAAAEJCAAAAACiA424AAAD2klEQVR42u3dwW7bQAwEUP//T6eHHgIU9mqGu3Jc5OmUpIkiPQMiPWTbx5fj7/FAQIIECRIkSJAgQYIECRIkSJAgQYLE/yTxuD7WP/HP15593/en67OsT/Xs0/7qSZAgQWJT4vVD9smNvNQJTvBSJ+BYm1T3RoIECRKbEutL3akJ61sKPlr/tur3kiBBgsSbJNZ3HdxIj5C+DCRIkCDxORL9pabZQdV8kyBBgsRHSAR/ur6i4GtpEdhOIEiQIEHiLontJ/yPfvTmaSAJEiR+r8TWulI4wupz4b6B7i6cBAkSJCYSfQKRphxBfRrO1NL3BSRIkCBxVqIaL61/4uVZgq2B7TC3YyNBggSJPYnhE7laNqhMDuYYJEiQIHFWIu2x13nqurIET/1khNWcmQQJEiRukBh2uMPbDGSHccrJKkqCBAkSV/100PX2haaagQ0Xug5l2yRIkCCRb6YGT/N+7XTn7zL1tz7dOCNBggSJK4ngrNU99Klx2jvf3W2TIEGCxFU+kTa3QYSbzsDSR/8wrpju8pMgQYJEOQOrxl9po10lFRV0f5AgQYLEpsQ6fOjXqaorr05VLaqSIEGCxDGJ4TCr6s/Tef9w2WBQA0mQIEFiIhEkFcMV+3Si1acN/YSMBAkSJM5KrKtIVSeGiwXD+Ldv8EmQIEFiLnHmXX9aCYJthWBltQckQYIEiRM5ZvVsrjYJqvOtv7mfvQ2SGhIkSJCIJPo8IU1WgzwhaKrTV2C/dpAgQYJE3m33DW/wzf3ka9iQn8wnSJAgQSJPVtM2vF9AqGpHtQKbRCckSJAgMZGoGugqCei76HShoWrISZAgQeKYxHCPKR3mV/Ouan62U0pIkCBB4sS/XdRvTfU5xrBnD94XHH/fQYIECRL59D4IbtMLHC6+DuvJfhUlQYIEiUnaEDSy1bLVcD01ld3PJ0iQIEGi3BpIs93uEpoxWb92sJ9tkyBBgkQ0A+uH/kFrvlOVKo79bpsECRIk9rYGupw0XPfv9/GDGd3d+xMkSJAgEcUL1YA/3cKqctweazADI0GCBIko0U1H88OQ4nF9pPOzPuAlQYIEiWMSpzvwdEM0SCWC06evKAkSJEjctWeVjv+rtYMzH/XTMBIkSJA4K7Ed0gZYQY2pGu20qJAgQYLEDRJ9YpBmwFUq0VeRQaZCggQJEndKpGFBkqceWTatBnUkSJAg8U6JYBE0SCWCKxi+KlXzTYIECRKbEn3QkNaJHitFSAsNCRIkSByTqFKE/oarCHcnn4gBSZAgQWL8//z8toMECRIkSJAgQYIECRIkSJAgQYIECRKfevwB/xVtL1UEI1YAAAAASUVORK5CYII="
        },
        "type" => "DUITNOW_QRCODE"
      }
    }

    case res2["code"] do
      "SUCCESS" ->
        Elixir.Task.start_link(__MODULE__, :query_transaction, [checkout_id, 0])
        b64 = res2 |> Map.get("item") |> Map.get("qrcode") |> Map.get("base64Image")
        ImageConverter.decode_and_save_as_bmp(b64, "so_#{s.id}.bmp")
        "so_#{s.id}.bmp"

      _ ->
        case res2["error"]["code"] do
          "DUPLICATE_REQUEST" ->
            Process.sleep(2000)
            get_qr(s, checkout_id)

          _ ->
            "test.bmp"
        end
    end
  end

  def query_transaction(checkout_id, count) do
    Process.sleep(3_000)

    if count < 5 do
      res = RevenueMonster.query_transaction(checkout_id)
      check = res |> Kernel.get_in(["item", "status"])

      case check do
        "SUCCESS" ->
          nil

        _ ->
          nil
          query_transaction(checkout_id, count + 1)
      end
    end
  end

  # ESP32 HTTP Polling Methods

  @doc """
  ESP32 Simple Polling - Returns JSON with pending tasks
  GET /iot/poll/:device_id
  """
  def esp32_poll(conn, %{"device_id" => device_id}) do
    tasks = get_esp32_tasks(device_id)

    json(conn, %{
      device_id: device_id,
      tasks: tasks,
      timestamp: System.system_time(:second)
    })
  end

  @doc """
  ESP32 SSE Streaming - Long polling with chunked response
  GET /iot/stream/:device_id
  """
  def esp32_stream(conn, %{"device_id" => device_id}) do
    conn =
      conn
      |> put_resp_content_type("text/event-stream")
      |> put_resp_header("cache-control", "no-cache")
      |> put_resp_header("connection", "keep-alive")
      |> send_chunked(200)

    # Send initial connection event
    {:ok, conn} =
      chunk(
        conn,
        "event: connected\ndata: #{Jason.encode!(%{device_id: device_id, status: "connected"})}\n\n"
      )

    # Stream tasks for up to 30 seconds
    Enum.reduce_while(
      # Poll 10 times (30 seconds total)
      1..10,
      conn,
      fn iteration, conn ->
        tasks = get_esp32_tasks(device_id)

        if tasks != [] do
          # Send tasks and halt
          event_data =
            Jason.encode!(%{
              device_id: device_id,
              tasks: tasks,
              timestamp: System.system_time(:second)
            })

          case chunk(conn, "event: task\ndata: #{event_data}\n\n") do
            {:ok, conn} ->
              # Clear tasks after sending
              clear_esp32_tasks(device_id)
              {:halt, conn}

            {:error, :closed} ->
              {:halt, conn}
          end
        else
          # Send heartbeat and continue
          heartbeat =
            Jason.encode!(%{
              device_id: device_id,
              heartbeat: true,
              iteration: iteration,
              timestamp: System.system_time(:second)
            })

          case chunk(conn, "event: heartbeat\ndata: #{heartbeat}\n\n") do
            {:ok, conn} ->
              # Wait 3 seconds
              Process.sleep(3000)
              {:cont, conn}

            {:error, :closed} ->
              {:halt, conn}
          end
        end
      end
    )
  end

  @doc """
  ESP32 Task Completion - Mark tasks as completed


  Endpoint: /iot/a7670c/complete/00000000-0000-0000-a0b7-65272c4
  Data: {"uuid":"b4de1b92-b8fc-4d0b-81c8-8340f9b4d379","action":"start","pin":16,"reps":5,"status":"completed"}


  POST /iot/complete/:device_id
  """
  def esp32_complete(conn, %{"device_id" => device_id} = params) do
    # Log task completion
    device_db_id = get_device_id_with_cache(device_id)

    if device_db_id do
      BlogEngine.Settings.create_device_log(%{
        device_id: device_db_id,
        uuid: params["uuid"] || Ecto.UUID.generate(),
        remarks: "HTTP polling task completed: #{params["task_type"] || "unknown"}"
      })
    end

    json(conn, %{
      status: "completed",
      device_id: device_id,
      timestamp: System.system_time(:second)
    })
  end

  # Helper functions for ESP32 task management

  defp get_esp32_tasks(device_id) do
    pid = Process.whereis(:esp32_tasks)

    if pid do
      Agent.get(pid, fn tasks -> Map.get(tasks, device_id, []) end)
    else
      []
    end
  end

  defp add_esp32_task(device_name, task) do
    pid = Process.whereis(:esp32_tasks)

    if pid do
      Agent.update(pid, fn tasks ->
        current_tasks = Map.get(tasks, device_name, [])
        Map.put(tasks, device_name, [task | current_tasks])
      end)
    end
  end

  defp clear_esp32_tasks(device_id) do
    pid = Process.whereis(:esp32_tasks)

    if pid do
      Agent.update(pid, fn tasks -> Map.delete(tasks, device_id) end)
    end
  end

  # Device Cache Management Functions

  defp get_device_id_from_cache(device_name) do
    pid = Process.whereis(:device_cache)

    if pid do
      Agent.get(pid, fn cache -> Map.get(cache, device_name) end)
    else
      nil
    end
  end

  defp cache_device_id(device_name, device_id) do
    pid = Process.whereis(:device_cache)

    if pid do
      Agent.update(pid, fn cache -> Map.put(cache, device_name, device_id) end)
    end
  end

  defp get_device_id_with_cache(device_name) do
    # First try to get from cache
    case get_device_id_from_cache(device_name) do
      nil ->
        # Cache miss - query database
        device = BlogEngine.Settings.get_device_by_name(device_name)
        if device do
          # Cache the result for future use
          cache_device_id(device_name, device.id)
          device.id
        else
          nil
        end
      
      device_id ->
        # Cache hit
        device_id
    end
  end

  defp invalidate_device_cache(device_name) do
    pid = Process.whereis(:device_cache)

    if pid do
      Agent.update(pid, fn cache -> Map.delete(cache, device_name) end)
    end
  end

  defp clear_device_cache() do
    pid = Process.whereis(:device_cache)

    if pid do
      Agent.update(pid, fn _cache -> %{} end)
    end
  end

  @doc """
  Bulk load devices into cache - useful for warming up the cache
  """
  def preload_device_cache() do
    devices = BlogEngine.Settings.list_devices()
    
    Enum.each(devices, fn device ->
      cache_device_id(device.name, device.id)
    end)
    
    length(devices)
  end

  @doc """
  Add task to ESP32 queue - called when payment is received
  """
  def queue_esp32_task(device_name, task_data) do
    task = %{
      uuid: task_data["uuid"],
      action: task_data["action"],
      format: task_data["format"],
      reps: task_data["reps"],
      delay: task_data["delay"],
      pin: task_data["pin"],
      timestamp: System.system_time(:second),
      created_at: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    add_esp32_task(device_name, task)

    # Log the queued task
    device_db_id = get_device_id_with_cache(device_name)

    if device_db_id do
      # BlogEngine.Settings.create_device_log(%{
      #   device_id: device_db_id,
      #   uuid: task.uuid,
      #   job_content: Jason.encode!(task),
      #   remarks: "HTTP polling task queued: #{task.action} with #{task.reps} reps"
      # })
    end

    task
  end

  @doc """
  Unified communication method - handles both WebSocket and HTTP polling
  """
  def send_device_command(device_name, command_data) do
    device_db_id = get_device_id_with_cache(device_name)

    if device_db_id do
      # Always queue for HTTP polling (supports both ESP32 WiFi and A7670C cellular)
      queue_esp32_task(device_name, command_data)

      # Also try WebSocket for WiFi connections (will fail gracefully for cellular)
      try do
        BlogEngineWeb.Endpoint.broadcast("user:#{device_name}", "start_pwm", command_data)
      rescue
        _ ->
          # WebSocket failed, HTTP polling will handle it
          Logger.info("WebSocket broadcast failed for #{device_name}, using HTTP polling")
      end

      # Log command for tracking
      Logger.info("Command sent to device #{device_name}: #{inspect(command_data)}")
    end
  end

  # A7670C Cellular Device HTTP Communication Methods

  @doc """
  A7670C Device Join - Initial device registration
  POST /iot/a7670c/join




  """
  def a7670c_join(conn, %{"device_id" => device_id} = params) do
    Logger.info("A7670C device joined: #{device_id}")

    # Use cached device ID for database operations
    device_db_id = get_device_id_with_cache(device_id)

    if device_db_id do
      # Get full device object only when we need configuration details
      device = BlogEngine.Settings.get_device!(device_db_id)
      
      # Log device join using cached ID
      BlogEngine.Settings.create_device_time_log(%{device_id: device_db_id})
      BlogEngineWeb.Endpoint.broadcast("user:#{device_id}", "i_am_online", %{})
      
      # Minimal response to fit A7670C 250-byte limit
      # Use short field names and essential data only
      response_data = %{
        s: "ok", # status
        id: device_id |> String.slice(-8..-1), # Last 8 chars only
        c: %{ # config
          p: device.default_io_pin || 16, # pin
          f: device.format || "pwm", # format
          b: 9600 # baud_rate
        },
        ts: System.system_time(:second) # timestamp
      }

      json(conn, response_data)
    else
      conn
      |> put_status(404)
      |> json(%{s: "error", r: "not found"}) # Minimal error response
    end
  end

  @doc """
  A7670C Polling - Returns pending commands and tasks
  GET /iot/a7670c/poll/:device_id
  """
  def a7670c_poll(conn, %{"device_id" => device_id}) do
    # Get pending tasks from the ESP32 task queue (reuse existing infrastructure)
    tasks = get_esp32_tasks(device_id)

    DeviceTracker.update_last_online(device_id)

    # Use cached device ID instead of database query
    device_db_id = get_device_id_with_cache(device_id)

    # Elixir.Task.start_link(BlogEngine.Settings, :create_device_time_log, [%{device_id: device_id}])
    
    if device_db_id do
      time_log = BlogEngine.Settings.create_device_time_log(%{device_id: device_db_id})
      IO.inspect(time_log, label: "time_log")
    end
    
    BlogEngineWeb.Endpoint.broadcast("user:#{device_id}", "i_am_online", %{})
    IO.inspect(tasks, label: "tasks")

    # Get any pending commands specific to A7670C
    commands = get_a7670c_commands(device_id)

    # Minimal response to fit A7670C 250-byte limit
    # Use short field names and minimal data
    response_data = %{
      id: device_id |> String.slice(-8..-1), # Last 8 chars only
      t: tasks |> Enum.map(fn task ->
        %{
          u: task.uuid , # Short UUID
          a: task.action,
          r: task.reps,
          d: task.delay,
          p: task.pin
        }
      end) |> Enum.take(1), # Limit to 1 task to stay under 250 bytes
      ts: System.system_time(:second)
    }

    # Clear tasks after sending (same as ESP32)
    if tasks != [] do
      clear_esp32_tasks(device_id)
    end

    json(conn, response_data)
  end

  @doc """
  A7670C Reading Submission - PWM readings, cash readings, etc.
  POST /iot/a7670c/reading/:device_id
  """
  def a7670c_reading(conn, %{"device_id" => device_id, "reading" => reading_data} = params) do
    Logger.info("Reading from A7670C device #{device_id}: #{inspect(reading_data)}")

    device = BlogEngine.Settings.get_device_by_name(device_id)

    if device do
      # Process the reading based on type
      case reading_data["type"] do
        "pwm" ->
          process_pwm_reading(device, reading_data)

        "cash" ->
          process_cash_reading(device, reading_data)

        "rs232" ->
          process_rs232_reading(device, reading_data)

        _ ->
          Logger.warn("Unknown reading type: #{reading_data["type"]}")
      end

      # Log the reading
      BlogEngine.Settings.create_device_log(%{
        device_id: device.id,
        uuid: reading_data["uuid"] || Ecto.UUID.generate(),
        remarks: "A7670C reading received: #{reading_data["type"]} - #{inspect(reading_data)}"
      })
    end

    json(conn, %{
      status: "received",
      device_id: device_id,
      timestamp: System.system_time(:second)
    })
  end

  @doc """
  A7670C Commands - Get pending commands for device
  GET /iot/a7670c/commands/:device_id
  """
  def a7670c_commands(conn, %{"device_id" => device_id}) do
    commands = get_a7670c_commands(device_id)

    json(conn, %{
      device_id: device_id,
      commands: commands,
      timestamp: System.system_time(:second)
    })
  end

  # Helper functions for A7670C support

  defp get_a7670c_device_settings(device_id) do
    device = BlogEngine.Settings.get_device_by_name(device_id)

    is_bill_acceptor = fn ->
      if device.is_rs232 do
        "bill_acceptor"
      else
        "pwm_machine"
      end
    end

    if device do
      %{
        pwm_config: %{
          input_pin: device.default_io_pin || 14
        },
        rs232_config: %{
          baud_rate: 9600,
          rx_pin: device.reading_pin || 32,  # Changed from 25 to 32
          tx_pin: device.default_io_pin || 33,  # Changed from 26 to 33
          protocol: "8N2",
          device_type: is_bill_acceptor.()
        },
        device_config: %{
          format: device.format || "pwm",
          default_pin: device.default_io_pin || 5,
          skip_first: device.skip_first || false
        }
      }
    else
      %{}
    end
  end

  defp get_a7670c_commands(device_id) do
    # Check for any pending commands in the database or cache
    # For now, return empty array - can be extended based on requirements
    []
  end

  defp process_pwm_reading(device, reading_data) do
    # Process PWM frequency readings
    frequency = reading_data["frequency"]
    pulse_count = reading_data["pulse_count"]

    Logger.info(
      "PWM Reading - Device: #{device.name}, Frequency: #{frequency}Hz, Pulses: #{pulse_count}"
    )

    # You can add logic here to:
    # - Store readings in database
    # - Trigger alerts based on frequency
    # - Update device status
  end

  defp process_cash_reading(device, reading_data) do
    # Process cash/bill acceptor readings
    value = reading_data["value"]
    bill_type = reading_data["device"]

    Logger.info("Cash Reading - Device: #{device.name}, Value: $#{value}, Type: #{bill_type}")

    # You can add logic here to:
    # - Record cash transactions
    # - Update device cash totals
    # - Trigger dispensing logic
  end

  defp process_rs232_reading(device, reading_data) do
    # Process RS232 device readings
    device_type = reading_data["device"]
    value = reading_data["value"]

    Logger.info("RS232 Reading - Device: #{device.name}, Type: #{device_type}, Value: #{value}")

    # You can add logic here to:
    # - Handle different RS232 device types
    # - Process device-specific data
    # - Update device states
  end
end
