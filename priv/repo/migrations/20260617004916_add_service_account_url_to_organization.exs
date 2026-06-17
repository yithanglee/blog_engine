defmodule BlogEngine.Repo.Migrations.AddServiceAccountUrlToOrganization do
  use Ecto.Migration

  def change do
    alter table("organizations") do
      add :service_account_url, :text
    end

  end
end
