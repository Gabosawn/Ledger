defmodule Ledger.Repo.Migrations.CrearUsuario do
  use Ecto.Migration

  def change do
    create table(:usuarios) do
      add :username, :string, size: 20, null: false
      add :nacimiento, :date, null: false
      timestamps()
    end
    create unique_index(:usuarios, [:username])
    create constraint(:usuarios, :username_length, check: "length(username) BETWEEN 5 AND 20")
    create constraint(:usuarios, :mayor_18, check: "nacimiento <= (CURRENT_DATE - INTERVAL '18 years')")
  end
end
