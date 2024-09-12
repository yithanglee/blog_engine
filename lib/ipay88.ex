defmodule Ipay88 do
  import SweetXml

  @gateway_url "https://payment.ipay88.com.my/ePayment/WebService/MHGatewayService/GatewayService.svc"
  @soap_action "https://www.mobile88.com/IGatewayService/EntryPageFunctionality"
  @url "https://payment.ipay88.com.my/epayment/entry.asp"
  def generate_signature(
        merchant_key,
        merchant_code,
        ref_no,
        amount,
        currency,
        x_field1,
        barcode_no,
        device_id
      ) do
    data =
      merchant_key <>
        merchant_code <>
        ref_no <> amount <> currency <> x_field1 <> barcode_no <> device_id

    IO.inspect(data)

    :crypto.hash(:sha256, data)
    |> Base.encode16(case: :lower)
  end

  def send_payment_request_test(amount, merchant_key, merchant_code, ref_no) do
    pre_amt = (amount * 100.00) |> :erlang.trunc()

    signature =
      generate_signature(
        merchant_key,
        merchant_code,
        ref_no,
        (100_000 + pre_amt)
        |> Integer.to_string()
        |> String.split("")
        |> Enum.reject(&(&1 == ""))
        |> List.pop_at(0)
        |> elem(1)
        |> Enum.join("")
        |> String.to_integer()
        |> Integer.to_string(),
        "MYR",
        "",
        "",
        ""
      )
      |> IO.inspect()
  end

  def send_payment_request(amount, merchant_key, merchant_code, ref_no) do
    pre_amt = (amount * 100.00) |> :erlang.trunc()

    signature =
      generate_signature(
        merchant_key,
        merchant_code,
        ref_no,
        (100_000 + pre_amt)
        |> Integer.to_string()
        |> String.split("")
        |> Enum.reject(&(&1 == ""))
        |> List.pop_at(0)
        |> elem(1)
        |> Enum.join("")
        |> String.to_integer()
        |> Integer.to_string(),
        "MYR",
        "",
        "",
        ""
      )
      |> IO.inspect()

    params = %{
      "MerchantCode" => merchant_code,
      "PaymentId" => "15",
      "RefNo" => ref_no,
      "Amount" => "#{amount}",
      "Currency" => "MYR",
      "ProdDesc" => "Photo Print",
      "UserName" => "John Tan",
      "UserEmail" => "john@hotmail.com",
      "UserContact" => "0126500100",
      "Remark" => "",
      "Lang" => "UTF-8",
      "SignatureType" => "SHA256",
      "Signature" => signature,
      "ResponseURL" => "https://blog.damienslab.com/thank_you",
      "BackendURL" => "https://blog.damienslab.com/api/payment/ipay88"
    }

    headers = [
      {"Content-Type", "application/x-www-form-urlencoded"},
      {"Origin", "https://netculture.co"}
    ]

    case HTTPoison.post(@url, URI.encode_query(params), headers) |> IO.inspect() do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        IO.puts("Request successful")
        IO.inspect(body)
        IO.puts(body)

      {:ok, %HTTPoison.Response{status_code: status_code}} ->
        IO.puts("Request failed with status code: #{status_code}")

      {:error, %HTTPoison.Error{reason: reason}} ->
        IO.puts("Request failed with reason: #{inspect(reason)}")
    end
  end

  def construct_soap_request(
        merchant_key,
        merchant_code,
        amount,
        ref_no,
        currency,
        prod_desc,
        device_id,
        user_name,
        user_email,
        user_contact
      ) do
    pre_amt = (amount * 100.00) |> :erlang.trunc()

    signature =
      generate_signature(
        merchant_key,
        merchant_code,
        ref_no,
        (100_000 + pre_amt)
        |> Integer.to_string()
        |> String.split("")
        |> Enum.reject(&(&1 == ""))
        |> List.pop_at(0)
        |> elem(1)
        |> Enum.join("")
        |> String.to_integer()
        |> Integer.to_string(),
        currency,
        "",
        "",
        ""
      )
      |> IO.inspect()

    callback = Application.get_env(:blog_engine, :ipay88)[:callback]

    ~s"""
    <soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:mob="https://www.mobile88.com" xmlns:mhp="http://schemas.datacontract.org/2004/07/MHPHGatewayService.Model">
      <soapenv:Header/>
      <soapenv:Body>
        <mob:EntryPageFunctionality>
          <mob:requestModelObj>
            <mhp:Amount>#{amount}</mhp:Amount>
            <mhp:BackendURL>#{callback}/api/payment/ipay88</mhp:BackendURL>
            <mhp:BarcodeNo></mhp:BarcodeNo>
            <mhp:Currency>#{currency}</mhp:Currency>
            <mhp:MerchantCode>#{merchant_code}</mhp:MerchantCode>
            <mhp:PaymentId>888</mhp:PaymentId>
            <mhp:ProdDesc>#{prod_desc}</mhp:ProdDesc>
            <mhp:RefNo>#{ref_no}</mhp:RefNo>
            <mhp:Remark>test</mhp:Remark>
            <mhp:Signature>#{signature}</mhp:Signature>
            <mhp:SignatureType>SHA256</mhp:SignatureType>
            <mhp:UserContact>#{user_contact}</mhp:UserContact>
            <mhp:UserEmail>#{user_email}</mhp:UserEmail>
            <mhp:UserName>#{user_name}</mhp:UserName>
            <mhp:lang>UTF-8</mhp:lang>
            <mhp:xfield1/>
          </mob:requestModelObj>
        </mob:EntryPageFunctionality>
      </soapenv:Body>
    </soapenv:Envelope>
    """
  end

  @doc """
  amount = 1.20
  ref_no = "testfirah4"
  currency = "MYR"
  prod_desc = "User fill 2.0"
  user_name = "damien lee"
  user_email = "yithanglee@gmail.com"
  user_contact = "0122664254"
  @merchant_key "Vx7AbhyzGK"
  @merchant_code "M15137"
  response = Ipay88.send_soap_request("Vx7AbhyzGK", "M15137", amount, ref_no, currency, prod_desc, device_id, user_name, user_email, user_contact)

  """
  def send_soap_request(
        mkey,
        mcode,
        amount,
        ref_no,
        currency,
        prod_desc,
        device_id,
        user_name,
        user_email,
        user_contact
      ) do
    soap_request =
      construct_soap_request(
        mkey,
        mcode,
        amount,
        ref_no,
        currency,
        prod_desc,
        device_id,
        user_name,
        user_email,
        user_contact
      )

    headers = [
      {"Content-Type", "text/xml;charset=UTF-8"},
      {"SOAPAction", @soap_action},
      {"Accept-Encoding", "gzip,deflate"}
    ]

    {:ok, resp} =
      HTTPoison.post(@gateway_url, soap_request, headers, recv_timeout: 30_000) |> IO.inspect()

    i = resp.body
    r = resp.request.body

    String.replace(r, "\"", "") |> IO.puts()
    String.replace(i, "\"", "") |> IO.puts()

    i
    |> xpath(
      ~x"//s:Envelope//s:Body//EntryPageFunctionalityResponse//EntryPageFunctionalityResult//a:QRCode//text()"
    )
    |> to_string
  end
end
