defmodule BlogEngine.Mailer do
  use Bamboo.Mailer, otp_app: :blog_engine
end

defmodule BlogEngine.Email do
  import Bamboo.Email
  import Bamboo.Phoenix

  use Bamboo.Phoenix, view: BlogEngineWeb.EmailView

  def custom_email(user_email, from_email, subject, html) do
    # Build your default email then customize for welcome
    base_email(from_email)
    |> to(user_email)
    |> subject(subject)
    |> put_header("Reply-To", from_email)
    |> render("custom_email.html", html: html)
  end

  def verification_email(user_email, from_email, brand_map, user_map \\ %{name: "there"}) do
    base_email(from_email)
    |> to(user_email)
    |> subject("Verification")
    |> put_header("Reply-To", from_email)
    |> render("verification_email.html", brand: brand_map, user: user_map)
  end

  def welcome_email(user_email, from_email, brand_map, user_map \\ %{name: "John Doe"}) do
    # Build your default email then customize for welcome
    base_email(from_email)
    |> to(user_email)
    |> subject("Welcome")
    |> put_header("Reply-To", from_email)
    |> render("welcome.html", brand: brand_map, user: user_map)
  end

  defp base_email(from_email) do
    new_email()
    |> from(from_email)
    |> put_html_layout({BlogEngineWeb.LayoutView, "email.html"})

    # Set default text layout
    # |> put_text_layout({BlogEngineWeb.LayoutView, "email.text"})
  end

  def send_verification_email(user_email, from_email, brand_map, user_map) do
    verification_email(user_email, from_email, brand_map, user_map)
    |> BlogEngine.Mailer.deliver_now()
  end
end

# BlogEngine.Email.welcome_email |> BlogEngine.Mailer.deliver_now
