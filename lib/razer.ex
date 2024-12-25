defmodule Razer do
  require Logger

  @endpoint Application.get_env(:blog_engine, :razer)[:endpoint]

  @redirect_url Application.get_env(:blog_engine, :url)
  # merchant_id Application.get_env(:blog_engine, :razer)[:mid]
  # vkey Application.get_env(:blog_engine, :razer)[:vkey]
  require IEx

  def staticqr(device_uid, outlet_name, merchant_id, vkey, setting_currency \\ "MYR") do
    {currency, pg} =
      case setting_currency do
        "SGD" ->
          {"SGD", "PayNowSQR"}

        _ ->
          {"MYR", "DuitNowSQR"}
      end

    generate_signature = fn ->
      merchant_id = merchant_id
      verify_key = vkey

      str = merchant_id <> "#{pg}" <> device_uid <> "#{currency}" <> "1" <> vkey
      IO.puts(str)
      md5 = :crypto.hash(:md5, str) |> Base.encode16(case: :lower)
      IO.puts(md5)
      md5
    end

    checksum = generate_signature.()

    url =
      "https://api.merchant.razer.com/RMS/API/staticqr/index.php?merchantID=#{merchant_id}&channel=#{pg}&orderid=#{device_uid}&currency=#{currency}&amount=1&bill_name=#{outlet_name}&bill_desc=itemdesc&checksum=#{checksum}"

    response = HTTPoison.get!(url)

    case response do
      %HTTPoison.Response{status_code: 200, body: body} ->
        IO.puts("Success: #{body}")
        Jason.decode!(body)

      %HTTPoison.Response{status_code: status_code} ->
        IO.puts("Error: HTTP #{status_code}")
        %{status: "error #{status_code}"}

      %HTTPoison.Error{reason: reason} ->
        IO.puts("Request failed: #{reason}")
        %{status: "error #{reason}"}
    end
  end

  def payment_page(channel, amt, reference_no, merchant_id, vkey) do
    amt =
      case Application.get_env(:blog_engine, :release) do
        :prod ->
          amt

        :dev ->
          amt

        _ ->
          "2.0"
      end

    generate_signature = fn ->
      merchant_id = merchant_id
      verify_key = vkey

      str = amt <> merchant_id <> reference_no <> vkey
      IO.puts(str)
      md5 = :crypto.hash(:md5, str) |> Base.encode16(case: :lower)
      IO.puts(md5)
      md5
    end

    user = %{
      fullname: "djtech",
      phone: "0122664254",
      username: "djtech",
      email: "support@djtech.com"
    }

    "#{@endpoint}/RMS/pay/#{merchant_id}/#{channel}.php?merchant_id=#{merchant_id}&amount=#{amt}&orderid=#{reference_no}&bill_name=#{user.username}&bill_email=#{user.email}&bill_mobile=#{user.phone}&bill_desc=#{reference_no}&vcode=#{generate_signature.()}"
  end

  def enquire_transaction(trx_id, amount, merchant_id, vkey) do
    url = "#{@endpoint}/RMS/API/gate-query/index.php"

    generate_signature = fn ->
      merchant_id = merchant_id
      verify_key = vkey

      str = trx_id <> merchant_id <> verify_key <> amount
      IO.puts(str)
      md5 = :crypto.hash(:md5, str) |> Base.encode16(case: :lower)
      IO.puts(md5)
      md5
    end

    params = [
      {"domain", merchant_id},
      {"txID", trx_id},
      {"amount", amount},
      {"skey", generate_signature.()}
    ]

    form = params |> Enum.into(%{}) |> Jason.encode!()

    with {:ok,
          %HTTPoison.Response{
            body: body,
            status_code: 200
          }} <-
           HTTPoison.post(
             url,
             {:multipart, params},
             [{"Content-Type", "multipart/form-data"}],
             @auth
           ) do
      body
      |> String.split("\n")
      |> Enum.map(&(&1 |> String.split("=")))
      |> Enum.map(&{hd(&1), List.last(&1)})
      |> Enum.into(%{})
    else
      _ ->
        %{}
    end
  end

  def channel_results() do
    single_map = %{
      "applepay_enabled" => 1,
      "channel_map" => %{
        "direct" => %{"request" => "CREDIT7", "response" => "CREDIT7"},
        "hosted" => %{"request" => "credit", "response" => "credit"},
        "offline" => %{"request" => "", "response" => ""},
        "seamless" => %{"request" => "credit16", "response" => "credit"},
        "seamlesspayment" => %{"request" => "credit", "response" => "credit"}
      },
      "channel_type" => "CC",
      "currency" => ["MYR", "SGD"],
      "googlepay_enabled" => 1,
      "logo_url_120x43" =>
        "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/120/visa-master.gif",
      "logo_url_16x16" =>
        "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/16/visa-master.gif",
      "logo_url_24x24" =>
        "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/24/visa-master.gif",
      "logo_url_32x32" =>
        "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/32/visa-master.gif",
      "logo_url_48x48" =>
        "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/48/visa-master.gif",
      "status" => 1,
      "title" => "Visa/Mastercard"
    }

    res = %{
      "result" => [
        %{
          "applepay_enabled" => 1,
          "channel_map" => %{
            "direct" => %{"request" => "CREDIT7", "response" => "CREDIT7"},
            "hosted" => %{"request" => "credit", "response" => "credit"},
            "offline" => %{"request" => "", "response" => ""},
            "seamless" => %{"request" => "credit16", "response" => "credit"},
            "seamlesspayment" => %{"request" => "credit", "response" => "credit"}
          },
          "channel_type" => "CC",
          "currency" => ["MYR", "SGD"],
          "googlepay_enabled" => 1,
          "logo_url_120x43" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/120/visa-master.gif",
          "logo_url_16x16" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/16/visa-master.gif",
          "logo_url_24x24" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/24/visa-master.gif",
          "logo_url_32x32" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/32/visa-master.gif",
          "logo_url_48x48" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/48/visa-master.gif",
          "status" => 1,
          "title" => "Visa/Mastercard"
        },
        %{
          "applepay_enabled" => 1,
          "channel_map" => %{
            "direct" => %{"request" => "AMB-W2W", "response" => "AMB-W2W"},
            "hosted" => %{"request" => "amb", "response" => "amb"},
            "seamless" => %{"request" => "amb", "response" => "amb"},
            "seamlesspayment" => %{"request" => "amb", "response" => "amb"}
          },
          "channel_type" => "IB",
          "currency" => ["MYR"],
          "googlepay_enabled" => 1,
          "logo_url_120x43" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/120/ambank.gif",
          "logo_url_16x16" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/16/ambank.gif",
          "logo_url_24x24" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/24/ambank.gif",
          "logo_url_32x32" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/32/ambank.gif",
          "logo_url_48x48" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/48/ambank.gif",
          "status" => 1,
          "title" => "AmOnline"
        },
        %{
          "applepay_enabled" => 1,
          "channel_map" => %{
            "direct" => %{"request" => "AFFIN-EPG", "response" => "AFFIN-EPG"},
            "hosted" => %{"request" => "affin-epg", "response" => "affin-epg"},
            "seamless" => %{"request" => "affinonline", "response" => "affin-epg"},
            "seamlesspayment" => %{
              "request" => "affin-epg",
              "response" => "affin-epg"
            }
          },
          "channel_type" => "IB",
          "currency" => ["MYR"],
          "googlepay_enabled" => 1,
          "logo_url_120x43" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/120/affin.gif",
          "logo_url_16x16" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/16/affin.gif",
          "logo_url_24x24" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/24/affin.gif",
          "logo_url_32x32" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/32/affin.gif",
          "logo_url_48x48" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/48/affin.gif",
          "status" => 1,
          "title" => "Affin Online"
        },
        %{
          "applepay_enabled" => 1,
          "channel_map" => %{
            "direct" => %{"request" => "CIMB-CLICKS", "response" => "CIMB-CLICKS"},
            "hosted" => %{"request" => "cimb", "response" => "cimb"},
            "seamless" => %{"request" => "cimbclicks", "response" => "cimb"},
            "seamlesspayment" => %{"request" => "cimb", "response" => "cimb"}
          },
          "channel_type" => "IB",
          "currency" => ["MYR"],
          "googlepay_enabled" => 1,
          "logo_url_120x43" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/120/cimb.gif",
          "logo_url_16x16" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/16/cimb.gif",
          "logo_url_24x24" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/24/cimb.gif",
          "logo_url_32x32" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/32/cimb.gif",
          "logo_url_48x48" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/48/cimb.gif",
          "status" => 1,
          "title" => "CIMB Clicks"
        },
        %{
          "applepay_enabled" => 1,
          "channel_map" => %{
            "direct" => %{"request" => "FPX_ABB", "response" => "FPX_ABB"},
            "hosted" => %{"request" => "FPX_ABB", "response" => "abb"},
            "offline" => %{"request" => "", "response" => ""},
            "seamless" => %{"request" => "fpx_abb", "response" => "abb"},
            "seamlesspayment" => %{"request" => "fpx_abb", "response" => "fpx_abb"}
          },
          "channel_type" => "IB",
          "currency" => ["RM", "MYR"],
          "googlepay_enabled" => 1,
          "logo_url_120x43" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/120/FPX_ABB_120.gif",
          "logo_url_16x16" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/16/fpx.gif",
          "logo_url_24x24" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/24/fpx.gif",
          "logo_url_32x32" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/32/fpx.gif",
          "logo_url_48x48" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/48/FPX_ABB_48.gif",
          "status" => 1,
          "title" => "Affin Bank (FPX)"
        },
        %{
          "applepay_enabled" => 1,
          "channel_map" => %{
            "direct" => %{"request" => "FPX_ABMB", "response" => "FPX_ABMB"},
            "hosted" => %{"request" => "FPX_ABMB", "response" => "alliancebank"},
            "seamless" => %{"request" => "fpx_abmb", "response" => "alliancebank"},
            "seamlesspayment" => %{
              "request" => "fpx_abmb",
              "response" => "FPX_ABMB"
            }
          },
          "channel_type" => "IB",
          "currency" => ["RM", "MYR"],
          "googlepay_enabled" => 1,
          "logo_url_120x43" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/120/FPX_ABMB_120.gif",
          "logo_url_16x16" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/16/fpx.gif",
          "logo_url_24x24" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/24/fpx.gif",
          "logo_url_32x32" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/32/fpx.gif",
          "logo_url_48x48" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/48/FPX_ABMB_48.gif",
          "status" => 1,
          "title" => "Alliance Bank Malaysia Berhad (FPX)"
        },
        %{
          "applepay_enabled" => 1,
          "channel_map" => %{
            "direct" => %{"request" => "FPX_AMB", "response" => "FPX_AMB"},
            "hosted" => %{"request" => "AMOnline", "response" => "amb"},
            "seamless" => %{"request" => "fpx_amb", "response" => "amb"},
            "seamlesspayment" => %{"request" => "fpx_amb", "response" => "amb"}
          },
          "channel_type" => "IB",
          "currency" => ["RM", "MYR"],
          "googlepay_enabled" => 1,
          "logo_url_120x43" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/120/FPX_AMB_120.gif",
          "logo_url_16x16" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/16/fpx.gif",
          "logo_url_24x24" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/24/fpx.gif",
          "logo_url_32x32" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/32/fpx.gif",
          "logo_url_48x48" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/48/FPX_AMB_48.gif",
          "status" => 1,
          "title" => "AmOnline (FPX)"
        },
        %{
          "applepay_enabled" => 1,
          "channel_map" => %{
            "direct" => %{"request" => "FPX_BIMB", "response" => "FPX_BIMB"},
            "hosted" => %{"request" => "BIMB", "response" => "bankislam"},
            "seamless" => %{"request" => "fpx_bimb", "response" => "bankislam"},
            "seamlesspayment" => %{
              "request" => "fpx_bimb",
              "response" => "bankislam"
            }
          },
          "channel_type" => "IB",
          "currency" => ["RM", "MYR"],
          "googlepay_enabled" => 1,
          "logo_url_120x43" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/120/FPX_BIMB_120.gif",
          "logo_url_16x16" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/16/fpx.gif",
          "logo_url_24x24" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/24/fpx.gif",
          "logo_url_32x32" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/32/fpx.gif",
          "logo_url_48x48" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/48/FPX_BIMB_48.gif",
          "status" => 1,
          "title" => "Bank Islam (FPX)"
        },
        %{
          "applepay_enabled" => 1,
          "channel_map" => %{
            "direct" => %{"request" => "FPX_BKRM", "response" => "FPX_BKRM"},
            "hosted" => %{"request" => "bankrakyat", "response" => "bkrm"},
            "seamless" => %{"request" => "fpx_bkrm", "response" => "bkrm"},
            "seamlesspayment" => %{
              "request" => "fpx_bkrm",
              "response" => "FPX_BKRM"
            }
          },
          "channel_type" => "IB",
          "currency" => ["RM", "MYR"],
          "googlepay_enabled" => 1,
          "logo_url_120x43" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/120/FPX_BKRM120.gif",
          "logo_url_16x16" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/16/fpx.gif",
          "logo_url_24x24" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/24/fpx.gif",
          "logo_url_32x32" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/32/fpx.gif",
          "logo_url_48x48" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/48/FPX_BKRM_48.gif",
          "status" => 1,
          "title" => "Bank Kerjasama Rakyat Malaysia (FPX)"
        },
        %{
          "applepay_enabled" => 1,
          "channel_map" => %{
            "direct" => %{"request" => "FPX_BMMB", "response" => "FPX_BMMB"},
            "hosted" => %{"request" => "bankmuamalat", "response" => "muamalat"},
            "seamless" => %{"request" => "fpx_bmmb", "response" => "muamalat"},
            "seamlesspayment" => %{
              "request" => "fpx_bmmb",
              "response" => "FPX_BMMB"
            }
          },
          "channel_type" => "IB",
          "currency" => ["RM", "MYR"],
          "googlepay_enabled" => 1,
          "logo_url_120x43" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/120/FPX_BMMB_120.gif",
          "logo_url_16x16" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/16/fpx.gif",
          "logo_url_24x24" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/24/fpx.gif",
          "logo_url_32x32" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/32/fpx.gif",
          "logo_url_48x48" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/48/FPX_BMMB_48.gif",
          "status" => 1,
          "title" => "Bank Muamalat (FPX)"
        },
        %{
          "applepay_enabled" => 1,
          "channel_map" => %{
            "direct" => %{"request" => "FPX_BSN", "response" => "FPX_BSN"},
            "hosted" => %{"request" => "FPX_BSN", "response" => "bsn"},
            "offline" => %{"request" => "", "response" => ""},
            "seamless" => %{"request" => "fpx_bsn", "response" => "bsn"},
            "seamlesspayment" => %{"request" => "fpx_bsn", "response" => "FPX_BSN"}
          },
          "channel_type" => "IB",
          "currency" => ["RM", "MYR"],
          "googlepay_enabled" => 1,
          "logo_url_120x43" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/120/FPX_BSN_120.gif",
          "logo_url_16x16" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/16/fpx.gif",
          "logo_url_24x24" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/24/fpx.gif",
          "logo_url_32x32" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/32/fpx.gif",
          "logo_url_48x48" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/48/FPX_BSN_48.gif",
          "status" => 1,
          "title" => "Bank Simpanan Nasional (FPX)"
        },
        %{
          "applepay_enabled" => 1,
          "channel_map" => %{
            "direct" => %{
              "request" => "FPX_CIMBCLICKS",
              "response" => "FPX_CIMBCLICKS"
            },
            "hosted" => %{"request" => "CIMBCLICKS", "response" => "cimb"},
            "seamless" => %{"request" => "fpx_cimbclicks", "response" => "cimb"},
            "seamlesspayment" => %{
              "request" => "fpx_cimbclicks",
              "response" => "cimb"
            }
          },
          "channel_type" => "IB",
          "currency" => ["RM", "MYR"],
          "googlepay_enabled" => 1,
          "logo_url_120x43" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/120/FPX_CIMBCLICKS_120.gif",
          "logo_url_16x16" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/16/fpx.gif",
          "logo_url_24x24" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/24/fpx.gif",
          "logo_url_32x32" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/32/fpx.gif",
          "logo_url_48x48" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/48/FPX_CIMBCLICKS_48.gif",
          "status" => 1,
          "title" => "CIMB Clicks (FPX)"
        },
        %{
          "applepay_enabled" => 1,
          "channel_map" => %{
            "direct" => %{"request" => "FPX_HLB", "response" => "FPX_HLB"},
            "hosted" => %{"request" => "HLBConnect", "response" => "hlb"},
            "seamless" => %{"request" => "fpx_hlb", "response" => "hlb"},
            "seamlesspayment" => %{"request" => "fpx_hlb", "response" => "hlb"}
          },
          "channel_type" => "IB",
          "currency" => ["RM", "MYR"],
          "googlepay_enabled" => 1,
          "logo_url_120x43" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/120/FPX_HLB_120.gif",
          "logo_url_16x16" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/16/fpx.gif",
          "logo_url_24x24" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/24/fpx.gif",
          "logo_url_32x32" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/32/fpx.gif",
          "logo_url_48x48" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/48/FPX_HLB_48.gif",
          "status" => 1,
          "title" => "Hong Leong Online (FPX)"
        },
        %{
          "applepay_enabled" => 1,
          "channel_map" => %{
            "direct" => %{"request" => "FPX_KFH", "response" => "FPX_KFH"},
            "hosted" => %{"request" => "FPX_KFH", "response" => "kuwait-finace"},
            "seamless" => %{"request" => "fpx_kfh", "response" => "kuwait-finace"},
            "seamlesspayment" => %{"request" => "fpx_kfh", "response" => "FPX_KFH"}
          },
          "channel_type" => "IB",
          "currency" => ["RM", "MYR"],
          "googlepay_enabled" => 1,
          "logo_url_120x43" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/120/FPX_KFH_120.gif",
          "logo_url_16x16" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/16/fpx.gif",
          "logo_url_24x24" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/24/fpx.gif",
          "logo_url_32x32" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/32/fpx.gif",
          "logo_url_48x48" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/48/FPX_KFH_48.gif",
          "status" => 1,
          "title" => "Kuwait Finance House (FPX)"
        },
        %{
          "applepay_enabled" => 1,
          "channel_map" => %{
            "direct" => %{"request" => "FPX_MB2U", "response" => "FPX_MB2U"},
            "hosted" => %{"request" => "MB2U", "response" => "maybank2u"},
            "seamless" => %{"request" => "fpx_mb2u", "response" => "maybank2u"},
            "seamlesspayment" => %{
              "request" => "fpx_mb2u",
              "response" => "maybank2u"
            }
          },
          "channel_type" => "IB",
          "currency" => ["RM", "MYR"],
          "googlepay_enabled" => 1,
          "logo_url_120x43" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/120/FPX_MB2U_120.gif",
          "logo_url_16x16" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/16/fpx.gif",
          "logo_url_24x24" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/24/fpx.gif",
          "logo_url_32x32" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/32/fpx.gif",
          "logo_url_48x48" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/48/FPX_MB2U_48.gif",
          "status" => 1,
          "title" => "Maybank2U (FPX)"
        },
        %{
          "applepay_enabled" => 1,
          "channel_map" => %{
            "direct" => %{"request" => "FPX_OCBC", "response" => "FPX_OCBC"},
            "hosted" => %{"request" => "FPX_OCBC", "response" => "ocbc"},
            "seamless" => %{"request" => "fpx_ocbc", "response" => "ocbc"},
            "seamlesspayment" => %{
              "request" => "fpx_ocbc",
              "response" => "fpx_ocbc"
            }
          },
          "channel_type" => "IB",
          "currency" => ["RM", "MYR"],
          "googlepay_enabled" => 1,
          "logo_url_120x43" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/120/FPX_OCBC_120.gif",
          "logo_url_16x16" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/16/fpx.gif",
          "logo_url_24x24" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/24/fpx.gif",
          "logo_url_32x32" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/32/fpx.gif",
          "logo_url_48x48" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/48/FPX_OCBC_48.gif",
          "status" => 1,
          "title" => "OCBC Bank (FPX)"
        },
        %{
          "applepay_enabled" => 1,
          "channel_map" => %{
            "direct" => %{"request" => "FPX_PBB", "response" => "FPX_PBB"},
            "hosted" => %{"request" => "PBB", "response" => "publicbank"},
            "seamless" => %{"request" => "fpx_pbb", "response" => "publicbank"},
            "seamlesspayment" => %{
              "request" => "fpx_pbb",
              "response" => "publicbank"
            }
          },
          "channel_type" => "IB",
          "currency" => ["RM", "MYR"],
          "googlepay_enabled" => 1,
          "logo_url_120x43" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/120/FPX_PBB_120.gif",
          "logo_url_16x16" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/16/fpx.gif",
          "logo_url_24x24" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/24/fpx.gif",
          "logo_url_32x32" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/32/fpx.gif",
          "logo_url_48x48" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/48/FPX_PBB_48.gif",
          "status" => 1,
          "title" => "Public Bank (FPX)"
        },
        %{
          "applepay_enabled" => 1,
          "channel_map" => %{
            "direct" => %{"request" => "FPX_RHB", "response" => "FPX_RHB"},
            "hosted" => %{"request" => "RHBNow", "response" => "rhb"},
            "seamless" => %{"request" => "fpx_rhb", "response" => "rhb"},
            "seamlesspayment" => %{"request" => "fpx_rhb", "response" => "rhb"}
          },
          "channel_type" => "IB",
          "currency" => ["RM", "MYR"],
          "googlepay_enabled" => 1,
          "logo_url_120x43" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/120/FPX_RHB_120.gif",
          "logo_url_16x16" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/16/fpx.gif",
          "logo_url_24x24" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/24/fpx.gif",
          "logo_url_32x32" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/32/fpx.gif",
          "logo_url_48x48" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/48/FPX_RHB_48.gif",
          "status" => 1,
          "title" => "RHB Now (FPX)"
        },
        %{
          "applepay_enabled" => 1,
          "channel_map" => %{
            "direct" => %{"request" => "FPX_SCB", "response" => "FPX_SCB"},
            "hosted" => %{"request" => "FPX_SCB", "response" => "scb"},
            "seamless" => %{"request" => "fpx_scb", "response" => "scb"},
            "seamlesspayment" => %{"request" => "fpx_scb", "response" => "fpx_scb"}
          },
          "channel_type" => "IB",
          "currency" => ["RM", "MYR"],
          "googlepay_enabled" => 1,
          "logo_url_120x43" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/120/FPX_SCB_120.gif",
          "logo_url_16x16" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/16/fpx.gif",
          "logo_url_24x24" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/24/fpx.gif",
          "logo_url_32x32" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/32/fpx.gif",
          "logo_url_48x48" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/48/FPX_SCB_48.gif",
          "status" => 1,
          "title" => "Standard Chartered Bank (FPX)"
        },
        %{
          "applepay_enabled" => 1,
          "channel_map" => %{
            "direct" => %{"request" => "FPX_UOB", "response" => "FPX_UOB"},
            "hosted" => %{"request" => "FPX_UOB", "response" => "uob"},
            "seamless" => %{"request" => "fpx_uob", "response" => "uob"},
            "seamlesspayment" => %{"request" => "fpx_uob", "response" => "FPX_UOB"}
          },
          "channel_type" => "IB",
          "currency" => ["RM", "MYR"],
          "googlepay_enabled" => 1,
          "logo_url_120x43" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/120/FPX_UOB_120.gif",
          "logo_url_16x16" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/16/fpx.gif",
          "logo_url_24x24" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/24/fpx.gif",
          "logo_url_32x32" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/32/fpx.gif",
          "logo_url_48x48" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/48/FPX_UOB_48.gif",
          "status" => 1,
          "title" => "United Oversea Bank (FPX)"
        },
        %{
          "applepay_enabled" => 1,
          "channel_map" => %{
            "direct" => %{"request" => "HLB-ONL", "response" => "HLB-ONL"},
            "hosted" => %{"request" => "hlb", "response" => "hlb"},
            "seamless" => %{"request" => "hlb", "response" => "hlb"},
            "seamlesspayment" => %{"request" => "hlb", "response" => "hlb"}
          },
          "channel_type" => "IB",
          "currency" => ["MYR"],
          "googlepay_enabled" => 1,
          "logo_url_120x43" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/120/hlb.gif",
          "logo_url_16x16" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/16/hlb.gif",
          "logo_url_24x24" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/24/hlb.gif",
          "logo_url_32x32" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/32/hlb.gif",
          "logo_url_48x48" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/48/hlb.gif",
          "status" => 1,
          "title" => "Hong Leong Online"
        },
        %{
          "applepay_enabled" => 1,
          "channel_map" => %{
            "direct" => %{"request" => "MB2U", "response" => "MB2U"},
            "hosted" => %{"request" => "maybank2u", "response" => "maybank2u"},
            "seamless" => %{"request" => "maybank2u", "response" => "maybank2u"},
            "seamlesspayment" => %{
              "request" => "maybank2u",
              "response" => "maybank2u"
            }
          },
          "channel_type" => "IB",
          "currency" => ["MYR"],
          "googlepay_enabled" => 1,
          "logo_url_120x43" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/120/mbb.gif",
          "logo_url_16x16" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/16/mbb.gif",
          "logo_url_24x24" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/24/mbb.gif",
          "logo_url_32x32" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/32/mbb.gif",
          "logo_url_48x48" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/48/mbb.gif",
          "status" => 1,
          "title" => "Maybank2u"
        },
        %{
          "applepay_enabled" => 1,
          "channel_map" => %{
            "direct" => %{"request" => "RHB-ONL", "response" => "RHB-ONL"},
            "hosted" => %{"request" => "rhb", "response" => "rhb"},
            "seamless" => %{"request" => "rhb", "response" => "rhb"},
            "seamlesspayment" => %{"request" => "rhb", "response" => "rhb"}
          },
          "channel_type" => "IB",
          "currency" => ["MYR"],
          "googlepay_enabled" => 1,
          "logo_url_120x43" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/120/rhb.gif",
          "logo_url_16x16" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/16/rhb.gif",
          "logo_url_24x24" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/24/rhb.gif",
          "logo_url_32x32" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/32/rhb.gif",
          "logo_url_48x48" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/48/rhb.gif",
          "status" => 1,
          "title" => "RHB Now"
        },
        %{
          "applepay_enabled" => 1,
          "channel_map" => %{
            "direct" => %{"request" => "CASH-711", "response" => "cash"},
            "hosted" => %{"request" => "cash", "response" => "cash"},
            "seamless" => %{"request" => "cash-711", "response" => "cash"},
            "seamlesspayment" => %{"request" => "cash", "response" => "cash"}
          },
          "channel_type" => "OTC",
          "currency" => ["MYR", "PHP"],
          "googlepay_enabled" => 1,
          "logo_url_120x43" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/120/7e.gif",
          "logo_url_16x16" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/16/7e.gif",
          "logo_url_24x24" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/24/7e.gif",
          "logo_url_32x32" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/32/7e.gif",
          "logo_url_48x48" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/48/7e.gif",
          "status" => 1,
          "title" => "7-Eleven"
        },
        %{
          "applepay_enabled" => 1,
          "channel_map" => %{
            "direct" => %{"request" => "CASH-711", "response" => "cash"},
            "hosted" => %{"request" => "cash", "response" => "cash"},
            "seamless" => %{"request" => "cash-711", "response" => "cash"},
            "seamlesspayment" => %{"request" => "cash", "response" => "cash"}
          },
          "channel_type" => "OTC",
          "currency" => ["MYR", "PHP"],
          "googlepay_enabled" => 1,
          "logo_url_120x43" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/120/7e.gif",
          "logo_url_16x16" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/16/7e.gif",
          "logo_url_24x24" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/24/7e.gif",
          "logo_url_32x32" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/32/7e.gif",
          "logo_url_48x48" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/48/7e.gif",
          "status" => 1,
          "title" => "7-Eleven"
        },
        %{
          "applepay_enabled" => 1,
          "channel_map" => %{
            "direct" => %{"request" => "", "response" => ""},
            "hosted" => %{"request" => "", "response" => ""},
            "offline" => %{"request" => "", "response" => "16"},
            "seamless" => %{"request" => "", "response" => ""},
            "seamlesspayment" => %{"request" => "", "response" => ""}
          },
          "channel_type" => "EWO",
          "currency" => ["RM", "MYR"],
          "googlepay_enabled" => 1,
          "logo_url_120x43" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/120/alipay.gif",
          "logo_url_16x16" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/16/alipay.gif",
          "logo_url_24x24" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/24/alipay.gif",
          "logo_url_32x32" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/32/alipay.gif",
          "logo_url_48x48" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/48/alipay.gif",
          "status" => 1,
          "title" => "Alipay-Spot"
        },
        %{
          "applepay_enabled" => 1,
          "channel_map" => %{
            "direct" => %{"request" => "", "response" => ""},
            "hosted" => %{"request" => "", "response" => ""},
            "offline" => %{"request" => "", "response" => "16"},
            "seamless" => %{"request" => "", "response" => ""},
            "seamlesspayment" => %{"request" => "", "response" => ""}
          },
          "channel_type" => "EWO",
          "currency" => ["RM", "MYR"],
          "googlepay_enabled" => 1,
          "logo_url_120x43" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/120/alipay.gif",
          "logo_url_16x16" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/16/alipay.gif",
          "logo_url_24x24" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/24/alipay.gif",
          "logo_url_32x32" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/32/alipay.gif",
          "logo_url_48x48" =>
            "https://d2x73ruoixi2ei.cloudfront.net/images/logos/channels/48/alipay.gif",
          "status" => 1,
          "title" => "Alipay-Spot"
        }
      ],
      "status" => true
    }

    res |> Kernel.get_in(["result"]) |> Enum.group_by(& &1["channel_type"])
  end

  def get_channels(merchant_id, vkey) do
    url = "#{@endpoint}/RMS/API/chkstat/channel_status.php"

    generate_signature = fn datetime ->
      merchant_id = merchant_id
      verify_key = vkey
      str = datetime <> merchant_id
      IO.puts(str)
      sha256 = :crypto.mac(:hmac, :sha256, verify_key, str) |> Base.encode16(case: :lower)
      IO.puts(sha256)
      sha256
    end

    datetime = NaiveDateTime.utc_now() |> Timex.format!("%Y%m%d%H%M%S", :strftime)

    params = [
      {"merchantID", merchant_id},
      {"datetime", datetime},
      {"skey", generate_signature.(datetime)}
    ]

    form = params |> Enum.into(%{}) |> Jason.encode!()

    with {:ok,
          %HTTPoison.Response{
            body: body,
            status_code: 200
          }} <-
           HTTPoison.post(
             url,
             {:multipart, params},
             [{"Content-Type", "multipart/form-data"}],
             @auth
           )
           |> IO.inspect(),
         {:ok, res} <- Jason.decode(body) |> IO.inspect() do
      res
    else
      _ ->
        %{}
    end
  end

  def generate_signature(txn_amount \\ "1.5", reference_no \\ "18570", merchant_id, vkey) do
    # Get MerchantID and VerifyKey from environment variables
    merchant_id = merchant_id
    vkey = vkey

    str = "#{txn_amount}#{merchant_id}#{reference_no}#{vkey}"
    # Log the concatenated string
    Logger.info("Concatenated String: #{str}")

    # MD5 encryption of the concatenated string
    str_md5 = :crypto.hash(:md5, str) |> Base.encode16(case: :lower)

    # You can then set this value in a global store, return it, or use it as needed
    Logger.info("MD5 Hash: #{str_md5}")

    str_md5
  end

  def init(
        channel \\ "FPX_MB2U",
        txn_amount \\ "2.50",
        reference_no \\ "HAHOTOPUP61",
        merchant_id,
        vkey
      ) do
    server_url = Application.get_env(:blog_engine, :url)
    payment = CommerceFront.Settings.get_payment_by_billplz_code(reference_no) |> IO.inspect()

    user =
      if payment.wallet_topup != nil do
        Map.get(payment.wallet_topup, :user)
      else
        z =
          Map.get(payment.sales, :registration_details)
          |> Jason.decode!()
          |> Map.get("user")
          |> Map.get("shipping")

        %{fullname: z["fullname"], phone: z["phone"], username: z["fullname"], email: ""}
      end

    txn_amount =
      case Application.get_env(:blog_engine, :release) do
        :prod ->
          txn_amount

        _ ->
          "2.0"
      end

    form_data = [
      {"MerchantID", merchant_id},
      {"ReferenceNo", reference_no},
      {"TxnType", "SALS"},
      {"TxnChannel", channel},
      {"TxnCurrency", "MYR"},
      {"TxnAmount", txn_amount},
      {"CustName", user.fullname},
      {"CustEmail", user.email},
      {"CustContact", user.phone},
      {"CustDesc", user.username},
      {"NotificationURL", "#{server_url}api/notification/razer"},
      {"ReturnURL", "#{server_url}thank_you"},
      {"CallbackURL", "#{server_url}api/payment/razer"},
      {"Signature", generate_signature(txn_amount, reference_no)}
    ]

    # Headers
    headers = [
      {"Content-Type", "multipart/form-data"}
    ]

    # Make the POST request
    case HTTPoison.post(
           "#{@endpoint}/RMS/API/Direct/1.4.0/index.php",
           {:multipart, form_data},
           headers
         )
         |> IO.inspect() do
      {:ok, %HTTPoison.Response{status_code: 200, body: response_body}} ->
        # Handle successful response
        # text(conn, response_body)
        res = response_body |> Jason.decode!() |> IO.inspect()
        status = res |> Map.get("status", true)

        if status == false do
          %{status: :error, reason: Map.get(res, "error_desc")}
        else
          url = res |> Kernel.get_in(["TxnData", "RequestURL"])
          params = res |> Kernel.get_in(["TxnData", "RequestData"])

          %{status: :ok, url: url, params: params}
        end

      {:error, %HTTPoison.Error{reason: reason}} ->
        # Handle error
        # send_resp(conn, 500, "Request failed: #{reason}")
        reason
        %{status: :error, reason: reason}
    end
  end
end
