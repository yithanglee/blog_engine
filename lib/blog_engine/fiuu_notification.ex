defmodule BlogEngine.FiuuNotification do
  @moduledoc """
  Applies a Fiuu (RazerMS) payment notification.

  `WebhookEdge` acknowledges the HTTP callback and publishes the form
  payload to ElasticMQ. `BlogEngine.Queue` calls `process/1`.
  """

  require Logger

  @doc """
  Runs the payment side effects for one Fiuu callback body.

  Returns `:ok`. Raises on unexpected failures so Broadway leaves the
  SQS message unacked and ElasticMQ can redeliver it.
  """
  def process(params) when is_map(params) do
    tranID = Map.get(params, "tranID")
    orderid = Map.get(params, "orderid") || ""

    check =
      BlogEngine.Settings.get_sale_by_payment_ref(tranID)
      |> IO.inspect(label: "sales_by_payment_ref")

    topup_check =
      if String.contains?(orderid, "TOPUP-") do
        BlogEngine.Settings.get_sale!(orderid |> String.replace("TOPUP-", ""))
      else
        nil
      end

    cond do
      check != nil ->
        IO.inspect("already paid")
        :ok

      topup_check != nil ->
        topup_sale = topup_check

        if topup_sale.status == :pending_payment && params["status"] == "00" do
          BlogEngine.Settings.complete_topup(topup_sale)
        end

        :ok

      !String.contains?(orderid, "SUBS") && check == nil && params["status"] == "00" ->
        complete_sale(params, tranID)
        :ok

      String.contains?(orderid, "SUBS") && params["status"] == "00" ->
        complete_subscription(params)
        :ok

      true ->
        Logger.info("fiuu notification unmatched orderid=#{orderid} status=#{params["status"]}")
        :ok
    end
  end

  defp complete_sale(params, tranID) do
    device = BlogEngine.Settings.get_device_by_short_name(params["orderid"])

    amt =
      case params["amount"] |> Float.parse() do
        {amt, _suf} ->
          if amt < 0 do
            1.0
          else
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

    sale = sale |> BlogEngine.Repo.preload(:sales_items)
    items = sale.sales_items |> IO.inspect()

    item =
      if items != [] do
        item = items |> List.first() |> Map.get(:item)

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
  end

  defp complete_subscription(params) do
    id =
      case params |> Map.get("orderid") |> String.replace("SUBS", "") |> Integer.parse() do
        {id, _} -> id
        _ -> nil
      end

    invoice = BlogEngine.Settings.get_invoice!(id)
    trx_status = params |> Map.get("status")

    if trx_status == "00" do
      BlogEngine.Settings.update_invoice(invoice, %{status: "paid"})

      invoice.outlet_subscriptions
      |> Enum.map(
        &(&1
          |> BlogEngine.Settings.update_outlet_subscription(%{status: "active"}))
      )
    else
      BlogEngine.Settings.update_invoice(invoice, %{status: "failed"})
    end
  end
end
