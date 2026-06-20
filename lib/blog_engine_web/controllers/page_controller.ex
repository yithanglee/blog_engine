defmodule BlogEngineWeb.PageController do
  use BlogEngineWeb, :controller
  require IEx

  @doc """
  from svt admin the link will redirect user to page index with login details?
  """
  def admin_override(conn, _params) do
    render(conn, "override.html")
  end

  def _thank_you(conn, params) do
    IO.inspect(params)

    %{
      "amount" => "2.50",
      "appcode" => "",
      "channel" => "FPX_MB2U",
      "currency" => "RM",
      "domain" => "MGhaho2u",
      "error_code" => "",
      "error_desc" => "",
      "extraP" => "{\"fpx_buyer_name\":\"LEE%20YIT%20HANG\",\"fpx_txn_id\":\"2403170834530847\"}",
      "orderid" => "HAHOTOPUP42",
      "paydate" => "2024-03-17 08:34:51",
      "skey" => "87a101336941e8a097cc03d19e14a9e2",
      "status" => "00",
      "tranID" => "2065317565"
    }

    id =
      params["orderid"]
      |> String.replace(Application.get_env(:blog_engine, :revenue_monster)[:prefix], "")

    sales = BlogEngine.Settings.get_sale!(id)

    with true <- params["status"] == "00",
         true <- sales != nil do
      sale = sales
      outlet = sales.outlet
      device = sales.device

      uuid = Ecto.UUID.generate()

      device = device |> BlogEngine.Repo.preload(:executor_board)

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

              %{reps: reps, delay: device.default_delay, name: "User fill #{amount}"}
            else
              item
            end
        else
          amount = sale.amount

          reps = (amount / outlet.price_per_minutes) |> :erlang.trunc()

          %{reps: reps, delay: device.default_delay, name: "User fill #{amount}"}
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
        BlogEngineWeb.ApiController.send_device_command(device.name, %{
          "action" => "start",
          "format" => format,
          "reps" => reps,
          "delay" => delay,
          "uuid" => uuid,
          "pin" => device.default_io_pin
        })
      end

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
    else
      _ ->
        %{status: "error"}
    end

    IO.inspect("it's thank you-ing!")
    render(conn, "thank_you.html", params)
  end

  def razer_payment(conn, %{"chan" => chan, "amt" => amt, "ref_no" => ref} = params) do
    id =
      ref
      |> String.replace(Application.get_env(:blog_engine, :revenue_monster)[:prefix], "")

    sales = BlogEngine.Settings.get_sale!(id)

    conn
    |> redirect(
      external: Razer.payment_page(chan, amt, ref, sales.outlet.mcode, sales.outlet.mkey)
    )
  end

  def subscription_payment(conn, %{"chan" => "billplz", "amt" => _amt, "ref_no" => ref} = params) do
    # using billplz service

    id =
      case params |> Map.get("ref_no") |> String.replace("SUBS", "") |> Integer.parse() do
        {id, _} -> id
        _ -> nil
      end

    invoice = BlogEngine.Settings.get_invoice!(id)

    grand_total = invoice.outlet_subscriptions |> Enum.map(& &1.amount) |> Enum.sum()

    billplz_res =
      Billplz.create_bill(
        email: invoice.organization.email,
        mobile: invoice.organization.phone,
        name: invoice.organization.name,
        amount: grand_total,
        reference_no: ref,
        callback_url:
          Application.get_env(:blog_engine, :billplz)[:callback] <> "/api/billplz_callback",
        description: "Subscription Payment"
      )

    {:ok, invoice} =
      BlogEngine.Settings.update_invoice(invoice, %{
        grand_total: grand_total,
        payment_webhook: elem(billplz_res, 1) |> Jason.encode!()
      })
      |> IO.inspect()

    case billplz_res do
      {:ok, resp} ->
        {:ok, invoice} =
          BlogEngine.Settings.update_invoice(invoice, %{
            payment_url: resp["url"]
          })

        conn
        |> redirect(external: resp["url"])

      _ ->
        conn
        |> put_flash(:error, "Something went wrong")
        |> redirect(to: "/")
    end
  end

  @doc """
  https://www.billplz.com/bills/0ec7af36b6d98239
  BlogEngineWeb.PageController.billplz_callback(%Plug.Conn{}, %{"paid" => "true", "url" => "https://www.billplz.com/bills/0b1ec6ceeb9f8ab1"})
  """
  def billplz_callback(conn, params) do
    IO.inspect(params)

    sample = %{
      "amount" => "110",
      "collection_id" => "cv91igee",
      "due_at" => "2026-3-16",
      "email" => "jdtech@gmail.com",
      "id" => "0093f13b46e7388d",
      "mobile" => "+60132664254",
      "name" => "DJTECH",
      "paid" => "true",
      "paid_amount" => "110",
      "paid_at" => "2026-03-16 23:32:44 +0800",
      "state" => "paid",
      "url" => "https://www.billplz.com/bills/0093f13b46e7388d",
      "x_signature" => "c606f0cfa64803be0fea2e858eeae8441c39744614d050957abaa742b7e38f38"
    }

    invoice = BlogEngine.Settings.get_invoice_by_payment_url(params["url"])

    case params["paid"] do
      "true" ->
        BlogEngine.Settings.update_invoice(invoice, %{
          status: "paid",
          payment_webhook: params |> Jason.encode!()
        })

        invoice.outlet_subscriptions
        |> Enum.map(&(&1 |> BlogEngine.Settings.update_outlet_subscription(%{status: "active"})))

      _ ->
        BlogEngine.Settings.update_invoice(invoice, %{
          status: :failed,
          payment_webhook: params |> Jason.encode!()
        })
    end

    conn = put_status(conn, 200)
    json(conn, %{status: "ok"})
  end

  def subscription_payment(conn, %{"chan" => chan, "amt" => _amt, "ref_no" => ref} = params) do
    id =
      case params |> Map.get("ref_no") |> String.replace("SUBS", "") |> Integer.parse() do
        {id, _} -> id
        _ -> nil
      end

    invoice = BlogEngine.Settings.get_invoice!(id)

    grand_total = invoice.outlet_subscriptions |> Enum.map(& &1.amount) |> Enum.sum()

    {:ok, invoice} =
      BlogEngine.Settings.update_invoice(invoice, %{
        grand_total: grand_total
      })
      |> IO.inspect()

    amt = invoice.grand_total

    conn
    |> redirect(
      external:
        Razer.payment_page(
          chan,
          "#{amt}",
          ref,
          "djtechplt_Dev",
          "e37344c535a8d12000294306994251a3",
          %{
            fullname: invoice.organization.name,
            phone: invoice.organization.phone,
            username: invoice.organization.name,
            email: invoice.organization.email
          }
        )
    )
  end

  @doc """
  BlogEngineWeb.PageController.notification(Phoenix.ConnTest.build_conn(), test_params)
  """

  def notification(conn, params) do
    IO.inspect(params)

    topup_params = %{
      "amount" => "1.00",
      "appcode" => "",
      "channel" => "RPP_DuitNowQR",
      "currency" => "RM",
      "domain" => "djtechplt_Dev",
      "error_code" => "",
      "error_desc" => "",
      "extraP" =>
        "{\"DbtrAgt\":\"MBBEMYKL\",\"DbtrAcct_Type\":\"SVGS\",\"TxnType\":\"DOMESTIC\",\"refundability\":\"true\",\"bank_issuer\":\"Maybank Berhad\",\"duitnowqr_indicator\":\"20260417MBBEMYKL030OQR73604100\",\"metadata\":\"[]\"}",
      "nbcb" => "2",
      "orderid" => "TOPUP-423",
      "paydate" => "2026-04-17 21:55:18",
      "skey" => "b05d9625780f818b5ab86ae40a57f7d9",
      "status" => "00",
      "tranID" => "3637513979"
    }

    test_params = %{
      "amount" => "1.00",
      "appcode" => "",
      "channel" => "PayNow-Offline_MP",
      "currency" => "SGD",
      "domain" => "djtechplt_Dev",
      "error_code" => "",
      "error_desc" => "",
      "nbcb" => "1",
      "orderid" => "441d-64cc4fbc",
      "paydate" => "2025-01-09 22:33:09",
      "skey" => "6158bfa4cecf2c9bd10dc26bbb5d2fd1",
      "status" => "00",
      "tranID" => "2628420327"
    }

    duitnow = %{
      "amount" => "0.50",
      "appcode" => "",
      "channel" => "RPP_DuitNowQR-Offline_MP",
      "currency" => "RM",
      "domain" => "djtechplt_Dev",
      "error_code" => "",
      "error_desc" => "",
      "extraP" =>
        "{\"DbtrAgt\":\"MBBEMYKL\",\"DbtrAcct_Type\":\"SVGS\",\"TxnType\":\"DOMESTIC\",\"refundability\":\"true\",\"bank_issuer\":\"Maybank Berhad\",\"duitnowqr_indicator\":\"20240914MBBEMYKL030OQR71089433\"}",
      "nbcb" => "2",
      "orderid" => "441d-64cc4fbc",
      "paydate" => "2024-09-14 07:29:12",
      "skey" => "510f3836a7422a75a683c97b6ce171ca",
      "status" => "00",
      "tranID" => "2390694614"
    }

    topup_duitnow = %{
      "amount" => "1.00",
      "appcode" => "",
      "channel" => "RPP_DuitNowQR",
      "currency" => "RM",
      "domain" => "djtechplt_Dev",
      "error_code" => "",
      "error_desc" => "",
      "extraP" =>
        "{\"DbtrAgt\":\"MBBEMYKL\",\"DbtrAcct_Type\":\"SVGS\",\"TxnType\":\"DOMESTIC\",\"refundability\":\"true\",\"bank_issuer\":\"Maybank Berhad\",\"duitnowqr_indicator\":\"20260617MBBEMYKL030OQR70818702\",\"metadata\":\"[]\"}",
      "nbcb" => "2",
      "orderid" => "TOPUP-427",
      "paydate" => "2026-06-17 18:22:31",
      "skey" => "4835dfb3f35ca29b2dd4b2abff85b533",
      "status" => "00",
      "tranID" => "3789155243"
    }

    #  BlogEngineWeb.PageController.notification(%Plug.Conn{}, duitnow)

    # get the device
    # orderid will be device's identifier
    online = %{
      "amount" => "2.00",
      "appcode" => "",
      "channel" => "maybank2u",
      "currency" => "RM",
      "domain" => "djtechplt_Dev",
      "error_code" => "FPX_1C",
      "error_desc" => "Buyer Choose Cancel At Login Page",
      "extraP" => "{\"fpx_txn_id\":\"2409212020160488\"}",
      "nbcb" => "2",
      "orderid" => "TST276",
      "paydate" => "2024-09-21 20:20:15",
      "skey" => "7b04708f6d610d9cdeed212e2b8b4ea9",
      "status" => "11",
      "tranID" => "2402348820"
    }

    tranID = Map.get(params, "tranID")

    check =
      BlogEngine.Settings.get_sale_by_payment_ref(tranID)
      |> IO.inspect(label: "sales_by_payment_ref")

    topup_check =
      if String.contains?(params["orderid"], "TOPUP-") do
        BlogEngine.Settings.get_sale!(Map.get(params, "orderid") |> String.replace("TOPUP-", ""))
      else
        nil
      end

    cond do
      check != nil ->
        IO.inspect("already paid")
        true

      topup_check != nil ->
        topup_sale = topup_check

        if topup_sale.status == :pending_payment && params["status"] == "00" do
          BlogEngine.Settings.complete_topup(topup_sale)
        end

        true

      !String.contains?(params["orderid"], "SUBS") && check == nil && params["status"] == "00" ->
        # probably need to check if the online trx will reach here...

        device = BlogEngine.Settings.get_device_by_short_name(params["orderid"])

        amt =
          case params["amount"] |> Float.parse() do
            {amt, _suf} ->
              if amt < 0 do
                1.0
              else
                # todo: add device round_down

                if device.is_round_down do
                  amt |> Float.floor()
                else
                  amt |> Float.round(1)
                end
              end

            _ ->
              1.0
          end

        {:ok, sale, device, outlet} =
          if device == nil do
            id =
              params["orderid"]
              |> String.replace(Application.get_env(:blog_engine, :revenue_monster)[:prefix], "")

            sales = BlogEngine.Settings.get_sale!(id)
            {:ok, sales, sales.device, sales.outlet}
          else
            # todo: add the tranID into ref then recheck for duplication
            {:ok, sales} =
              BlogEngine.Settings.create_sale(%{
                uid: Ecto.UUID.generate(),
                amount: amt,
                outlet_id: device.outlet.id,
                organization_id: device.organization_id,
                device_id: device.id,
                payment_channel: "duitnowsqr",
                sales_date: Date.utc_today(),
                payment_ref: tranID
              })
              |> IO.inspect()

            outlet = device.outlet
            {:ok, sales, device, outlet}
          end

        uuid = Ecto.UUID.generate()

        device = device |> BlogEngine.Repo.preload(:executor_board)

        executor_board = device.executor_board

        device =
          if executor_board != nil do
            executor_board
          else
            device
          end

        # items = sale.sales_items |> IO.inspect()

        amount = sale.amount

        # reps = (amount / outlet.price_per_minutes) |> :erlang.trunc()
        # item = %{reps: reps, delay: 0.5, name: "User fill #{amount}"}
        sale = sale |> BlogEngine.Repo.preload(:sales_items)
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

                %{reps: reps, delay: device.default_delay, name: "User fill #{amount}"}
              else
                item
              end
          else
            amount = sale.amount

            reps = (amount / outlet.price_per_minutes) |> :erlang.trunc()

            %{reps: reps, delay: device.default_delay, name: "User fill #{amount}"}
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
          BlogEngineWeb.ApiController.send_device_command(device.name, %{
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

      String.contains?(params["orderid"], "SUBS") && params["status"] == "00" ->
        # probably a subscription payment

        sample = %{
          "amount" => "1.10",
          "appcode" => "",
          "channel" => "TNG-EWALLET",
          "currency" => "RM",
          "domain" => "djtechplt_Dev",
          "error_code" => "",
          "error_desc" => "",
          "extraP" => "{\"metadata\":\"[]\"}",
          "nbcb" => "2",
          "orderid" => "SUBS1",
          "paydate" => "2026-03-07 17:42:17",
          "skey" => "e1cd15589f9cfbe146814753424e0beb",
          "status" => "00",
          "tranID" => "3545036806"
        }

        id =
          case params |> Map.get("orderid") |> String.replace("SUBS", "") |> Integer.parse() do
            {id, _} -> id
            _ -> nil
          end

        invoice = BlogEngine.Settings.get_invoice!(id)
        trx_status = params |> Map.get("status")

        if trx_status == "00" do
          BlogEngine.Settings.update_invoice(invoice, %{
            status: "paid"
            # webhook_details: params |> Jason.encode!()
          })

          invoice.outlet_subscriptions
          |> Enum.map(
            &(&1
              |> BlogEngine.Settings.update_outlet_subscription(%{status: "active"}))
          )
        else
          BlogEngine.Settings.update_invoice(invoice, %{
            status: "failed"
            # webhook_details: params |> Jason.encode!()
          })
        end

      true ->
        IO.inspect("nothing match")
        true
    end

    json(conn, %{})
  end

  def index(conn, _params) do
    IO.inspect("it's reloading!")
    render(conn, "index.html")
  end

  def login(conn, _params) do
    render(conn, "login.html")
  end

  def html(conn, params) do
    app_dir = Application.app_dir(:blog_engine)
    path = app_dir <> "/priv/static/html/v2/#{params["path"] |> Enum.join("/")}"

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

    case File.read(path) do
      {:ok, bin} ->
        bin = bin |> String.replace("   ", "")

        translate = fn keyword, html ->
          if keyword == "Sales History" && html |> String.contains?("Sales History") do
            # IEx.pry()
          end

          String.replace(html, keyword, translation_map[keyword])
        end

        final_html =
          Enum.reduce(Map.keys(translation_map), bin, &translate.(&1, &2)) |> IO.inspect()

        append_cache_request = fn conn ->
          # conn
          # |> put_resp_header("cache-control", "max-age=900, must-revalidate")
          conn
        end

        conn
        |> append_cache_request.()
        |> put_resp_content_type("document/html")
        |> send_resp(200, final_html)

      _ ->
        final_html = ""

        conn
        |> put_resp_content_type("document/html")
        |> send_resp(200, final_html)
    end
  end

  def pdf_preview(conn, %{"id" => id, "type" => "do"} = params) do
    sale = BlogEngine.Settings.get_sale!(id)

    conn
    |> render("do_pdf.html",
      title: "Delivery Order",
      sale: sale,
      order_lines: sale.sales_items,
      layout: {BlogEngineWeb.LayoutView, "blank.html"}
    )
  end

  def pdf(conn, %{"id" => id, "type" => "do"} = params) do
    sale = BlogEngine.Settings.get_sale!(id)

    server_url = "http://localhost:4000"
    server_url = Application.get_env(:blog_engine, :url)

    html =
      Phoenix.View.render_to_string(
        BlogEngineWeb.PageView,
        "do_pdf.html",
        conn: conn,
        merchant: nil,
        title: "Delivery Order",
        sale: sale,
        order_lines: sale.sales_items
      )
      |> String.replace("/images", "#{server_url}/images")

    IO.inspect(server_url)

    css = "<link rel='stylesheet' href='#{server_url}/css/app.css' >
        <link rel='stylesheet' href='#{server_url}/css/all.css' >"

    pdf_params = %{
      "html" => "<!DOCTYPE html><html><head>#{css}</head><body>#{html}</body></html>"
    }

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
      "attachment; filename=\"DeliveryOrder_#{params["id"]}.pdf\""
    )
    |> send_resp(200, pdf_binary)
  end

  def pdf_preview(conn, %{"id" => id, "type" => "merchant_do"} = params) do
    sale = BlogEngine.Settings.get_sale!(id) |> BlogEngine.Repo.preload(:merchant)

    conn
    |> render("do_pdf.html",
      title: "Delivery Order",
      merchant: sale.merchant,
      sale: sale,
      order_lines: sale.sales_items,
      layout: {BlogEngineWeb.LayoutView, "blank.html"}
    )
  end

  def pdf(conn, %{"id" => id, "type" => "merchant_do"} = params) do
    sale =
      BlogEngine.Settings.get_sale!(id)
      |> BlogEngine.Repo.preload(:merchant)

    server_url = "http://localhost:4000"
    server_url = Application.get_env(:blog_engine, :url)

    html =
      Phoenix.View.render_to_string(
        BlogEngineWeb.PageView,
        "do_pdf.html",
        conn: conn,
        merchant: sale.merchant,
        title: "Delivery Order",
        sale: sale,
        order_lines: sale.sales_items
      )
      |> String.replace("/images", "#{server_url}/images")

    IO.inspect(server_url)

    css = "<link rel='stylesheet' href='#{server_url}/css/app.css' >
        <link rel='stylesheet' href='#{server_url}/css/all.css' >"

    pdf_params = %{
      "html" => "<!DOCTYPE html><html><head>#{css}</head><body>#{html}</body></html>"
    }

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
      "attachment; filename=\"DeliveryOrder_#{params["id"]}.pdf\""
    )
    |> send_resp(200, pdf_binary)
  end

  def pdf_preview(conn, %{"id" => id, "type" => "merchant"} = params) do
    sale = BlogEngine.Settings.get_sale!(id) |> BlogEngine.Repo.preload(:merchant)

    conn
    |> render("co_pdf.html",
      title: "Invoice",
      merchant: sale.merchant,
      sale: sale,
      order_lines: sale.sales_items,
      layout: {BlogEngineWeb.LayoutView, "blank.html"}
    )
  end

  def pdf(conn, %{"id" => id, "type" => "merchant"} = params) do
    sale =
      BlogEngine.Settings.get_sale!(id)
      |> BlogEngine.Repo.preload(:merchant)

    server_url = "http://localhost:4000"
    server_url = Application.get_env(:blog_engine, :url)

    html =
      Phoenix.View.render_to_string(
        BlogEngineWeb.PageView,
        "co_pdf.html",
        conn: conn,
        merchant: sale.merchant,
        title: "Invoice",
        sale: sale,
        order_lines: sale.sales_items
      )
      |> String.replace("/images", "#{server_url}/images")

    IO.inspect(server_url)

    css = "<link rel='stylesheet' href='#{server_url}/css/app.css' >
        <link rel='stylesheet' href='#{server_url}/css/all.css' >"

    pdf_params = %{
      "html" => "<!DOCTYPE html><html><head>#{css}</head><body>#{html}</body></html>"
    }

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
      "attachment; filename=\"Invoice_#{params["id"]}.pdf\""
    )
    |> send_resp(200, pdf_binary)
  end

  def pdf_preview(conn, %{"id" => id, "type" => "invoice"} = params) do
    invoice = BlogEngine.Settings.get_invoice_with_details!(id)

    conn
    |> render("invoice_pdf.html",
      title: "Invoice",
      invoice: invoice,
      order_lines: invoice.outlet_subscriptions,
      layout: {BlogEngineWeb.LayoutView, "blank.html"}
    )
  end

  def pdf(conn, %{"id" => id, "type" => "invoice"} = params) do
    invoice = BlogEngine.Settings.get_invoice_with_details!(id)

    server_url = "http://localhost:4000"
    server_url = Application.get_env(:blog_engine, :url)

    html =
      Phoenix.View.render_to_string(
        BlogEngineWeb.PageView,
        "invoice_pdf.html",
        conn: conn,
        title: "Invoice",
        invoice: invoice,
        order_lines: invoice.outlet_subscriptions
      )
      |> String.replace("/images", "#{server_url}/images")

    IO.inspect(server_url)

    css =
      "<link rel='stylesheet' href='#{server_url}/css/app.css' ><link rel='stylesheet' href='#{server_url}/css/all.css' >"

    pdf_params = %{
      "html" => "<!DOCTYPE html><html><head>#{css}</head><body>#{html}</body></html>"
    }

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
      "attachment; filename=\"Invoice_#{params["id"]}.pdf\""
    )
    |> send_resp(200, pdf_binary)
  end

  def pdf_preview(conn, %{"id" => id} = params) do
    sale = BlogEngine.Settings.get_sale!(id)

    conn
    |> render("co_pdf.html",
      title: "Invoice",
      sale: sale,
      merchant: nil,
      order_lines: sale.sales_items,
      layout: {BlogEngineWeb.LayoutView, "blank.html"}
    )
  end

  def pdf(conn, %{"id" => id} = params) do
    sale = BlogEngine.Settings.get_sale!(id)

    server_url = "http://localhost:4000"
    server_url = Application.get_env(:blog_engine, :url)

    html =
      Phoenix.View.render_to_string(
        BlogEngineWeb.PageView,
        "co_pdf.html",
        conn: conn,
        merchant: nil,
        title: "Invoice",
        sale: sale,
        order_lines: sale.sales_items
      )
      |> String.replace("/images", "#{server_url}/images")

    IO.inspect(server_url)

    css = "<link rel='stylesheet' href='#{server_url}/css/app.css' >
        <link rel='stylesheet' href='#{server_url}/css/all.css' >"

    pdf_params = %{
      "html" => "<!DOCTYPE html><html><head>#{css}</head><body>#{html}</body></html>"
    }

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
      "attachment; filename=\"Invoice_#{params["id"]}.pdf\""
    )
    |> send_resp(200, pdf_binary)
  end

  def authenticate(conn, params) do
    case check_password(params) do
      {true, user} ->
        conn
        |> put_session(:current_user, BluePotion.s_to_map(user))
        |> redirect(to: "/home")

      _ ->
        conn
        |> redirect(to: "/login")
    end
  end

  def check_password(params) do
    # your auth method here

    user = BlogEngine.Settings.get_user_by_username(params["username"])

    if user != nil do
      crypted_password =
        :crypto.hash(:sha512, params["password"]) |> Base.encode16() |> String.downcase()

      {crypted_password == user.crypted_password, user}
    else
      false
    end
  end

  def thank_you(conn, params) do
    IO.inspect("it's reloading!")
    IO.inspect(params, label: "params")

    sample = %{
      "amount" => "1.00",
      "appcode" => "",
      "channel" => "RPP_DuitNowQR",
      "currency" => "RM",
      "domain" => "djtechplt_Dev",
      "error_code" => "",
      "error_desc" => "",
      "extraP" =>
        "{\"DbtrAgt\":\"MBBEMYKL\",\"DbtrAcct_Type\":\"SVGS\",\"TxnType\":\"DOMESTIC\",\"refundability\":\"true\",\"bank_issuer\":\"Maybank Berhad\",\"duitnowqr_indicator\":\"20260417MBBEMYKL030OQR73027724\",\"metadata\":\"[]\"}",
      "orderid" => "TOPUP-421",
      "paydate" => "2026-04-17 17:35:28",
      "skey" => "6730bd9e50787e212e7345f3f9381534",
      "status" => "00",
      "tranID" => "3636894200"
    }

    merchant_code = Map.get(params, "MerchantCode")

    if merchant_code != nil do
      BlogEngineWeb.ApiController.ipay88_payment(conn, params)
    end

    sample = %{
      "amount" => "2.50",
      "appcode" => "",
      "channel" => "FPX_MB2U",
      "currency" => "RM",
      "domain" => "MGhaho2u",
      "error_code" => "",
      "error_desc" => "",
      "extraP" => "{\"fpx_buyer_name\":\"LEE%20YIT%20HANG\",\"fpx_txn_id\":\"2403170834530847\"}",
      "orderid" => "HAHOTOPUP42",
      "paydate" => "2024-03-17 08:34:51",
      "skey" => "87a101336941e8a097cc03d19e14a9e2",
      "status" => "00",
      "tranID" => "2065317565"
    }

    render(conn, "thank_you.html", params)

    # need to redirect back to the website..
  end

  # =============================================================================
  # OTA (Over-The-Air) Firmware Update Functions
  # =============================================================================

  def check_firmware_version(conn, %{"device_id" => device_id}) do
    device = BlogEngine.Settings.get_device_by_name(device_id)

    if device do
      current_version = get_latest_firmware_version_for_device(device)
      device_current_version = device.current_firmware_version || "1.0.0"

      # Check if update is available
      update_available = current_version != device_current_version

      response = %{
        current_version: current_version,
        device_version: device_current_version,
        update_available: update_available,
        download_url: BlogEngine.Settings.list_firmwares() |> List.first() |> Map.get(:url),
        mandatory: is_mandatory_update(device, current_version),
        changelog: get_firmware_changelog(current_version),
        timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
      }

      json(conn, response)
    else
      conn
      |> put_status(404)
      |> json(%{error: "Device not found"})
    end
  end

  def firmware_download(conn, %{"device_id" => device_id, "version" => version}) do
    device = BlogEngine.Settings.get_device_by_name(device_id)

    if device && authorized_for_firmware?(device, version) do
      # Get firmware from database by version
      firmware = get_firmware_by_version(version)

      case firmware do
        nil ->
          conn
          |> put_status(404)
          |> json(%{error: "Firmware version not found"})

        firmware ->
          # Download firmware from URL

          case File.read("#{Application.app_dir(:blog_engine)}/priv/static/#{firmware.url}") do
            {:ok, binary} ->
              # Log firmware download
              log_firmware_download(device, version)

              # Debug: Log request details for A7670C troubleshooting
              user_agent = get_req_header(conn, "user-agent") |> List.first() || "unknown"
              # Temporarily disable debug logs to prevent contamination of binary response
              # if String.contains?(user_agent, "ESP32") do
              #   IO.inspect("A7670C firmware request: #{device_id} v#{version}")
              #   IO.inspect("Range header: #{inspect(get_req_header(conn, "range"))}")
              #   IO.inspect("User-Agent: #{user_agent}")
              #   IO.inspect("All request headers:")
              #   Enum.each(conn.req_headers, fn {key, value} ->
              #     IO.inspect("  #{key}: #{value}")
              #   end)
              #
              #   # Check for Range in different header formats
              #   range_headers = [
              #     get_req_header(conn, "range"),
              #     get_req_header(conn, "Range"),
              #     get_req_header(conn, "RANGE"),
              #     get_req_header(conn, "http-range")
              #   ]
              #   IO.inspect("Range header variants: #{inspect(range_headers)}")
              # end

              range = get_req_header(conn, "range") |> List.first()

              # SIMCom A7670C embeds Range header in User-Agent - extract it
              range =
                if range == nil and String.contains?(user_agent, "Range: bytes=") do
                  # A7670C may accumulate multiple ranges - get the LAST one
                  # More specific regex to capture the range properly
                  range_matches = Regex.scan(~r/\\r\\nRange: bytes=([0-9]+\-[0-9]+)/, user_agent)

                  # Fallback to simpler pattern if the above doesn't match
                  range_matches =
                    if range_matches == [] do
                      range_matches = Regex.scan(~r/Range: bytes=([0-9]+\-[0-9]+)/, user_agent)
                      range_matches
                    else
                      range_matches
                    end

                  range_match = List.last(range_matches)

                  if range_match do
                    range = "bytes=" <> Enum.at(range_match, 1)
                    # Disable debug to prevent contamination
                    # if String.contains?(user_agent, "ESP32") do
                    #   IO.inspect("A7670C: Extracted Range from User-Agent: #{range}")
                    #   IO.inspect("A7670C: Total ranges found: #{length(range_matches)}")
                    #   IO.inspect("A7670C: All range matches: #{inspect(range_matches)}")
                    # end
                    range
                  else
                    # Disable debug to prevent contamination
                    # if String.contains?(user_agent, "ESP32") do
                    #   IO.inspect("A7670C: Failed to extract Range from User-Agent")
                    #   IO.inspect("A7670C: User-Agent content: #{inspect(user_agent)}")
                    # end
                    nil
                  end
                else
                  range
                end

              size = byte_size(binary)

              # Disable debug to prevent contamination
              # # Debug: Show exactly what range value we have before case statement
              # if String.contains?(user_agent, "ESP32") do
              #   IO.inspect("A7670C: Final range value for case statement: #{inspect(range)}")
              #   IO.inspect("A7670C: Range is_binary: #{is_binary(range)}")
              #   IO.inspect("A7670C: Range != nil: #{range != nil}")
              #   IO.inspect("A7670C: Range != \"\": #{range != ""}")
              # end

              conn =
                conn
                |> put_resp_content_type("application/octet-stream")
                |> put_resp_header("accept-ranges", "bytes")
                |> put_resp_header("x-firmware-version", version)
                |> put_resp_header("x-firmware-size", "#{size}")
                |> put_resp_header("x-device-id", device_id)
                |> put_resp_header("x-checksum", calculate_firmware_checksum(binary))
                |> put_resp_header("x-firmware-name", firmware.name)

              case range do
                nil ->
                  # No range header - send full file
                  # Disable debug to prevent contamination
                  # if String.contains?(user_agent, "ESP32") do
                  #   IO.inspect("A7670C: Sending full file (#{size} bytes)")
                  # end
                  send_resp(conn, 200, binary)

                range_value when is_binary(range_value) and range_value != "" ->
                  # Handle both standard "bytes=..." and extracted ranges
                  spec =
                    case range_value do
                      "bytes=" <> range_spec -> range_spec
                      # Already in "start-end" format
                      _ -> range_value
                    end

                  # Disable debug to prevent contamination
                  # if String.contains?(user_agent, "ESP32") do
                  #   IO.inspect("A7670C: Processing range: #{range_value} -> spec: #{spec}")
                  # end

                  # Parse range specification
                  [s, e] = String.split(spec, "-")
                  start = String.to_integer(s)

                  stop =
                    case e do
                      "" -> size - 1
                      _ -> String.to_integer(e)
                    end

                  start = max(0, start)
                  stop = min(size - 1, stop)
                  len = stop - start + 1

                  # Disable debug to prevent contamination
                  # # Debug for A7670C
                  # if String.contains?(user_agent, "ESP32") do
                  #   IO.inspect("A7670C: Range #{start}-#{stop}/#{size} (#{len} bytes)")
                  # end

                  # Validate range
                  if start >= size or stop < start do
                    conn
                    |> put_status(416)
                    |> put_resp_header("content-range", "bytes */#{size}")
                    |> send_resp(416, "")
                  else
                    part = :binary.part(binary, start, len)

                    conn
                    |> put_resp_header("content-range", "bytes #{start}-#{stop}/#{size}")
                    |> put_resp_header("content-length", "#{len}")
                    |> send_resp(206, part)
                  end

                _ ->
                  # Invalid range header format
                  # Disable debug to prevent contamination
                  # if String.contains?(user_agent, "ESP32") do
                  #   IO.inspect("A7670C: Invalid range header: #{inspect(range)}")
                  # end
                  send_resp(conn, 200, binary)
              end

            {:error, reason} ->
              conn
              |> put_status(502)
              |> json(%{error: "Failed to download firmware: #{reason}"})
          end
      end
    else
      conn
      |> put_status(403)
      |> json(%{error: "Unauthorized or invalid device"})
    end
  end

  # Helper functions for firmware management
  defp get_latest_firmware_version_for_device(_device) do
    # Get the latest firmware version from database
    case get_latest_firmware() do
      nil -> "1.0.0"
      firmware -> firmware.version
    end
  end

  defp get_firmware_by_version(version) do
    BlogEngine.Settings.list_firmwares()
    |> Enum.find(&(&1.version == version))
  end

  defp get_latest_firmware() do
    BlogEngine.Settings.list_firmwares()
    |> Enum.sort_by(& &1.version, :desc)
    |> List.first()
  end

  defp download_firmware_from_url(url) do
    case HTTPoison.get(url) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        {:ok, body}

      {:ok, %HTTPoison.Response{status_code: status_code}} ->
        {:error, "HTTP #{status_code}"}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, reason}
    end
  end

  defp is_mandatory_update(_device, _version) do
    # Determine if this is a mandatory security update
    # Could check firmware metadata for mandatory flag
    false
  end

  defp get_firmware_changelog(version) do
    case get_firmware_by_version(version) do
      nil ->
        "No changelog available"

      firmware ->
        case Jason.decode(firmware.metadata || "{}") do
          {:ok, metadata} -> metadata["changelog"] || "No changelog available"
          _ -> "No changelog available"
        end
    end
  end

  defp authorized_for_firmware?(device, version) do
    # Check if device is authorized for this firmware version
    # Could include checks for:
    # - Device type compatibility
    # - Organization permissions
    # - Beta/stable channel access
    device != nil and version in get_available_versions_for_device(device)
  end

  defp get_available_versions_for_device(_device) do
    # Return list of available firmware versions for this device from database
    BlogEngine.Settings.list_firmwares()
    |> Enum.map(& &1.version)
  end

  defp calculate_firmware_checksum(binary) do
    :crypto.hash(:sha256, binary) |> Base.encode16(case: :lower)
  end

  defp log_firmware_download(device, version) do
    # Log the firmware download for audit purposes
    IO.inspect("Firmware download: Device #{device.name} downloaded version #{version}")

    # Create firmware log entry
    BlogEngine.Settings.create_firmware_log(%{
      device_id: device.id,
      action: "download",
      version: version
    })
  end
end
