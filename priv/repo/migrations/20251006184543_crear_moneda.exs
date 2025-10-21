defmodule Ledger.Repo.Migrations.CrearMoneda do
  use Ecto.Migration

  def change do
    create table(:monedas) do
      add :nombre, :string, size: 4, null: false
      add :precio_dolar, :decimal, null: false
      timestamps()
    end

    create unique_index(:monedas, [:nombre])
    create constraint(:monedas, :moneda_positiva, check: "precio_dolar > 0")
    create constraint(:monedas, :nombre_upper_and_3_4, check: "nombre ~ '^[A-Z]{3,4}$'")
  end
end
