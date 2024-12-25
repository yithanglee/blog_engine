defmodule BlogEngineWeb.PageController do
  use BlogEngineWeb, :controller
  require IEx

  @doc """
  from svt admin the link will redirect user to page index with login details?
  """
  def admin_override(conn, _params) do
    render(conn, "override.html")
  end

  def thank_you(conn, params) do
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
        BlogEngineWeb.Endpoint.broadcast("user:#{device.name}", "start_pwm", %{
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

  def notification(conn, params) do
    IO.inspect(params)

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
      "orderid" => "DEMO637",
      "paydate" => "2024-09-14 07:29:12",
      "skey" => "510f3836a7422a75a683c97b6ce171ca",
      "status" => "00",
      "tranID" => "2390694614"
    }

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

    if params["status"] == "00" do
      # probably need to check if the online trx will reach here...

      device = BlogEngine.Settings.get_device_by_short_name(params["orderid"])

      amt =
        case params["amount"] |> Float.parse() do
          {amt, _suf} ->
            if amt < 0 do
              1.0
            else
              amt |> Float.floor()
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
          {:ok, sales} =
            BlogEngine.Settings.create_sale(%{
              uid: Ecto.UUID.generate(),
              amount: amt,
              outlet_id: device.outlet.id,
              organization_id: device.organization_id,
              device_id: device.id,
              payment_channel: "duitnowsqr",
              sales_date: Date.utc_today()
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
        BlogEngineWeb.Endpoint.broadcast("user:#{device.name}", "start_pwm", %{
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
    merchant_code = Map.get(params, "MerchantCode")

    if merchant_code != nil do
      BlogEngineWeb.ApiController.ipay88_payment(conn, params)
    end

    render(conn, "thank_you.html", params)
  end
end
