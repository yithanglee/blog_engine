defmodule BlogEngine.Repo.Migrations.AddExecutorBoardToDevices do
  use Ecto.Migration

  def change do
    alter table("devices") do 
      add :executor_board_id, :integer
    end
  end
end
