defmodule BlogEngineWeb.ApiController do
  use BlogEngineWeb, :controller

  alias BlogEngine.{Repo, Settings}

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

  require IEx

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
        "get_time" ->
          timestamp = DateTime.utc_now() |> DateTime.to_unix()
          %{time: timestamp}

        "pay_service" ->
          outlet_item = Settings.get_item!(params["id"]) |> BluePotion.sanitize_struct()
          device = Settings.get_device_by_name(params["device"])

          # todo: check the connection health, last 10 seconds was there any count...

          res = BlogEngine.Settings.check_last_mins(device.id)

          if res <= 60 do
            {:ok, s} =
              Settings.create_sale(%{
                sales_date: Date.utc_today(),
                outlet_id: outlet_item.outlet.id,
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

            case outlet_item.outlet.payment_gateway do
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
          end

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

        "get_items" ->
          Settings.list_items_by_subdomain(params["code"])
          |> Enum.map(
            &(&1
              |> BluePotion.sanitize_struct()
              |> Map.take([:id, :name, :price, :image_url, :short_name2, :short_name1]))
          )

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

        BlogEngineWeb.Endpoint.broadcast("user:#{device.name}", "start_pwm", %{
          "action" => "start",
          "reps" => item.reps,
          "delay" => item.delay,
          "uuid" => uuid,
          "pin" => device.default_io_pin
        })

        BlogEngine.Settings.create_device_log(%{
          device_id: device.id,
          uuid: uuid,
          job_content:
            Jason.encode!(%{
              "action" => "start",
              "reps" => item.reps,
              "delay" => item.delay,
              "uuid" => uuid,
              "pin" => device.default_io_pin
            }),
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

    order = params

    sale =
      BlogEngine.Settings.get_sale!(
        Map.get(order, "RefNo")
        |> String.replace("#{Application.get_env(:blog_engine, :revenue_monster)[:prefix]}", "")
      )
      |> IO.inspect()

    outlet = BlogEngine.Settings.get_outlet!(sale.outlet_id)
    status = Map.get(params, "Status") |> IO.inspect()

    case status do
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

                %{reps: reps, delay: 0.2, name: "User fill #{amount}"}
              else
                item
              end
          else
            amount = sale.amount

            reps = (amount / outlet.price_per_minutes) |> :erlang.trunc()

            %{reps: reps, delay: 0.2, name: "User fill #{amount}"}
          end

        BlogEngineWeb.Endpoint.broadcast("user:#{device.name}", "start_pwm", %{
          "action" => "start",
          "reps" => item.reps,
          "delay" => item.delay,
          "uuid" => uuid,
          "pin" => device.default_io_pin
        })

        BlogEngine.Settings.create_device_log(%{
          device_id: device.id,
          uuid: uuid,
          job_content:
            Jason.encode!(%{
              "action" => "start",
              "reps" => item.reps,
              "delay" => item.delay,
              "uuid" => uuid,
              "pin" => device.default_io_pin
            }),
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

    json(conn, %{status: "ok"})
  end

  def post(conn, params) do
    res =
      case params["scope"] do
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

          BlogEngineWeb.Endpoint.broadcast("user:#{params["name"]}", "start_pwm", %{
            "action" => params["action"],
            "reps" => params["value"],
            "delay" => params["delay"],
            "uuid" => uuid,
            "pin" => device.default_io_pin
          })

          BlogEngine.Settings.create_device_log(%{
            device_id: device.id,
            uuid: uuid,
            job_content:
              Jason.encode!(%{
                "action" => params["action"],
                "reps" => params["value"],
                "delay" => params["delay"],
                "uuid" => uuid,
                "pin" => device.default_io_pin
              }),
            remarks: "manual start #{params["item_name"]} on pin #{device.default_io_pin}"
          })

          %{status: "ok"}

        "sync_menu" ->
          params["_json"] |> Settings.populate_menus() |> IO.inspect()
          %{status: "ok"}

        "approve_merchant" ->
          Settings.approve_merchant(params)
          %{status: "ok"}

        "disable_merchant" ->
          Settings.disable_merchant(params)
          %{status: "ok"}

        "do_adjustment" ->
          Settings.approve_adjustment(params)
          %{status: "ok"}

        "admin_menus" ->
          params["list"] |> Settings.update_admin_menus()

          %{status: "ok"}

        "admin_modify_referral" ->
          BlogEngine.Settings.change_referral(
            params["username"],
            params["to_new_placement_username"]
          )

          %{status: "ok"}

        "admin_modify_placement" ->
          BlogEngine.Settings.change_placement(
            params["username"],
            params["to_new_placement_username"],
            params["position"]
          )

          %{status: "ok"}

        "admin_insert_wallet_trx" ->
          sample = %{user_id: 609, amount: 1100.00, remarks: "something", wallet_type: "register"}
          ewallet = BlogEngine.Settings.get_ewallet!(params["ewallet_id"]) |> IO.inspect()

          nparams =
            params
            |> Map.put("amount", params["amount"] |> Float.parse() |> elem(0))
            |> Map.merge(%{"user_id" => ewallet.user_id, "wallet_type" => ewallet.wallet_type})
            |> Enum.reduce(%{}, fn {key, value}, acc ->
              acc |> Map.put(String.to_atom(key), value)
            end)

          BlogEngine.Settings.create_wallet_transaction(nparams)

          %{status: "ok"}

        "admin_register_member" ->
          sample = %{
            "scope" => "admin_register_member",
            "user" => %{
              "email" => "888@1.com",
              "fullname" => "w2",
              "password" => "[FILTERED]",
              "phone" => "888",
              "placement" => %{"position" => "left"},
              "sponsor" => "wer1",
              "username" => "wer2"
            }
          }

          case Settings.register_without_products(params["user"]) do
            {:ok, multi_res} ->
              %{status: "ok"}

            {:error, _model, changeset, succeeded} ->
              errors = changeset.errors |> Keyword.keys()

              {reason, message} = changeset.errors |> hd()
              {proper_message, message_list} = message
              final_reason = Atom.to_string(reason) <> " " <> proper_message
              %{status: "error", reason: final_reason}
          end

        "mark_do" ->
          sale = Settings.get_sale!(params["id"]) |> IO.inspect()

          cond do
            sale.status == :processing && params["status"] == "pending_delivery" ->
              Settings.update_sale(sale, %{status: params["status"]})
              %{status: "ok"}

            sale.status == :pending_delivery && params["status"] == "sent" ->
              Settings.mark_sent(params, sale)

              %{status: "ok"}

            true ->
              nil
              %{status: "error", reason: "already updated to #{params["status"]}"}
          end

        # params["status"]

        "pay_reward" ->
          Settings.pay_unpaid_bonus(
            Date.from_erl!({params["year"], params["month"], params["day"]}),
            [params["name"]]
          )

          %{status: "ok"}

        "transfer_wallet" ->
          sample = %{
            "_csrf_token" => "Cw1XLQAKA3NeCHYCARBvKGo3WTkmGBN5ic4u_mF9mcEvRO8YSG0kkK_7",
            "convert" => %{"user_id" => "583"},
            "scope" => "transfer_wallet",
            "transfer" => %{"amount" => "100.00", "username" => "summer"}
          }

          Settings.transfer_wallet(
            params["transfer"]["user_id"],
            params["transfer"]["username"],
            Float.parse(params["transfer"]["amount"]) |> elem(0)
          )

        "convert_wallet" ->
          Settings.convert_wallet(
            params["convert"]["user_id"],
            Float.parse(params["convert"]["amount"]) |> elem(0)
          )

        "approve_merchant_withdrawal" ->
          params["id"]
          |> Settings.approve_merchant_withdrawal()
          |> case do
            {:ok, _res} ->
              %{status: "ok"}

            {:error, "already paid"} ->
              %{status: "error", reason: "already paid"}

            _ ->
              %{status: "error"}
          end

        "approve_withdrawal_batch" ->
          params["id"]
          |> Settings.approve_withdrawal_batch()
          |> case do
            {:ok, _res} ->
              %{status: "ok"}

            {:error, "already paid"} ->
              %{status: "error", reason: "already paid"}

            _ ->
              %{status: "error"}
          end

        "approve_topup" ->
          case Settings.approve_topup(params) do
            {:ok, multi_res} ->
              %{status: "ok"}

            {:error, "already approved"} ->
              %{status: "error", reason: "already approved"}

            _ ->
              %{status: "error", reason: "unknown"}
          end

        "manual_approve_fpx" ->
          with payment <-
                 Settings.get_payment_by_billplz_code(params["id"]),
               true <- payment != nil,
               true <- payment.sales != nil,
               sales <- payment.sales,
               {:ok, register_params} <- sales.registration_details |> Jason.decode() do
            case Settings.register(register_params["user"], sales) do
              {:ok, multi_res} ->
                %{status: "ok", res: multi_res |> BluePotion.sanitize_struct()}

              _ ->
                %{status: "error"}
            end
          else
            _ ->
              %{status: "ok"}
          end

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
                role_app_routes:
                  user.role.app_routes |> Enum.map(&(&1 |> BluePotion.sanitize_struct()))
              }

            {false, _res} ->
              %{status: "error", reason: "Invalid credentials"}
          end

        "topup" ->
          case Settings.create_topup_transaction(params) do
            {:ok, multi_res} ->
              %{status: "ok", res: multi_res.payment |> BluePotion.sanitize_struct()}

            _ ->
              %{status: "error"}
          end

        "merchant_checkout" ->
          # get the billplz link first, then make payment
          # create the sales first
          # Settings.register(params["user"])

          case Settings.create_sales_transaction(params) |> IO.inspect() do
            {:ok, multi_res} ->
              %{status: "ok", res: multi_res.payment |> BluePotion.sanitize_struct()}

            {:error, "Please check cart items."} ->
              %{status: "error", reason: "Please check cart items."}

            {:error, :payment, "not sufficient", passed_cg} ->
              %{status: "error", reason: "wallet balance not sufficient"}

            _ ->
              %{status: "error"}
          end

        "redeem" ->
          # get the billplz link first, then make payment
          # create the sales first
          # Settings.register(params["user"])

          case Settings.create_sales_transaction(params) |> IO.inspect() do
            {:ok, multi_res} ->
              %{status: "ok", res: multi_res.payment |> BluePotion.sanitize_struct()}

            {:error, "Please check cart items."} ->
              %{status: "error", reason: "Please check cart items."}

            {:error, :payment, "not sufficient", passed_cg} ->
              %{status: "error", reason: "wallet balance not sufficient"}

            _ ->
              %{status: "error"}
          end

        "upgrade" ->
          # get the billplz link first, then make payment
          # create the sales first
          # Settings.register(params["user"])

          sales_person = Settings.get_user!(params["user"]["sales_person_id"])

          with true <-
                 params["user"]["upgrade"] == "" ||
                   params["user"]["upgrade"] == sales_person.username,
               true <- params["user"]["payment"]["method"] == "register_point" do
            %{status: "error", reason: "Cannot use DRP on self."}
          else
            _ ->
              case Settings.create_sales_transaction(params) |> IO.inspect() do
                {:ok, multi_res} ->
                  %{
                    status: "ok",
                    res: multi_res.payment |> Map.delete(:user) |> BluePotion.sanitize_struct()
                  }

                {:error, "Please check cart items."} ->
                  %{status: "error", reason: "Please check cart items."}

                {:error, "Too much drp used."} ->
                  %{status: "error", reason: "Too much drp used."}

                {:error, :payment, "not sufficient", passed_cg} ->
                  %{status: "error", reason: "wallet balance not sufficient"}

                _ ->
                  %{status: "error"}
              end
          end

        "link_register" ->
          # get the billplz link first, then make payment
          # create the sales first
          # Settings.register(params["user"])
          case Settings.create_sales_transaction(params) |> IO.inspect() do
            {:ok, multi_res} ->
              %{status: "ok", res: multi_res.payment |> BluePotion.sanitize_struct()}

            {:error, :payment, "not sufficient", passed_cg} ->
              %{status: "error", reason: "wallet balance not sufficient"}

            {:error, "Too much drp used."} ->
              %{status: "error", reason: "Too much drp used."}

            {:error, "Please enter a password."} ->
              %{status: "error", reason: "Please enter a password."}

            {:error, "Please check cart items."} ->
              %{status: "error", reason: "Please check cart items."}

            {:error, "Sponsor cannot be Shopper to register new member."} ->
              %{status: "error", reason: "sponsor cannot be Shopper to register new member."}

            _ ->
              %{status: "error", reason: "Please contact admin."}
          end

        "register" ->
          # get the billplz link first, then make payment
          # create the sales first
          # Settings.register(params["user"])
          case Settings.create_sales_transaction(params) |> IO.inspect() do
            {:ok, multi_res} ->
              %{status: "ok", res: multi_res.payment |> BluePotion.sanitize_struct()}

            {:error, :payment, "not sufficient", passed_cg} ->
              %{status: "error", reason: "wallet balance not sufficient"}

            {:error, "Too much drp used."} ->
              %{status: "error", reason: "Too much drp used."}

            {:error, "Please enter a password."} ->
              %{status: "error", reason: "Please enter a password."}

            {:error, "Please check cart items."} ->
              %{status: "error", reason: "Please check cart items."}

            {:error, "Sponsor cannot be Shopper to register new member."} ->
              %{status: "error", reason: "sponsor cannot be Shopper to register new member."}

            _ ->
              %{status: "error", reason: "Please contact admin."}
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
    parent_id = Map.get(params, "parent_id")

    params =
      if parent_id != nil do
        params
        |> Map.put(
          "parent_id",
          BlogEngine.Settings.decode_corporate_account_token(parent_id).id
        )
      else
        params
      end

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
        preloads
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
end
