defmodule Ledger.Repo.Migrations.HacerTransaccion do
  use Ecto.Migration

  def change do
    create table(:transacciones) do
      add :moneda_origen_id, references(:monedas, on_delete: :restrict), null: false
      add :moneda_destino_id, references(:monedas, on_delete: :restrict), null: true
      add :cuenta_origen_id, references(:usuarios, on_delete: :restrict), null: false
      add :cuenta_destino_id, references(:usuarios, on_delete: :restrict), null: true
      add :monto, :decimal, null: false
      add :tipo, :string, null: false
      timestamps()
    end

    create index(:transacciones, [:moneda_origen_id])
    create index(:transacciones, [:moneda_destino_id])
    create index(:transacciones, [:cuenta_origen_id])
    create index(:transacciones, [:cuenta_destino_id])
    create constraint(:transacciones, :monto_positivo, check: "monto >= 0")
    create constraint(:transacciones, :tipos_disponibles, check: "tipo in ('alta_cuenta', 'swap', 'transferencia')")
    create constraint(:transacciones, :cuentas_iguales, check: "tipo <> 'transferencia' OR cuenta_origen_id <> cuenta_destino_id")
    create constraint(:transacciones, :swap_existe_cuenta_destino, check: "tipo <> 'swap' OR cuenta_destino_id IS NULL")
    create constraint(:transacciones, :alta_existe_cuenta_destino, check: "tipo <> 'alta_cuenta' OR cuenta_destino_id IS NULL")
    create constraint(:transacciones, :alta_existe_moneda_destino, check: "tipo <> 'alta_cuenta' OR moneda_destino_id IS NULL")
  end
end
