defmodule BlogEngine.Repo.Migrations.AddQrCodeData do
  use Ecto.Migration

  def change do
    alter table("devices") do
      add :qr_code_data, :binary
    end
  end
end
