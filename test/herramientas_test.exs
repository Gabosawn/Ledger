defmodule HerramientasTest do
  use ExUnit.Case

  setup do
    # 1. Checkout del sandbox
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Ledger.Repo)

    {:ok, _} = Ledger.Usuario.changeset(:crear_usuario, %{username: "Gabriel", nacimiento: Date.new!(2003, 7, 14)})
    {:ok, _} = Ledger.Usuario.changeset(:crear_usuario, %{username: "Heinly", nacimiento: Date.new!(2003, 7, 14)})
    {:ok, _} = Ledger.Usuario.changeset(:crear_usuario, %{username: "Jordan", nacimiento: Date.new!(2003, 7, 14)})
    {:ok, _} = Ledger.Moneda.changeset(:crear_moneda, %{nombre: "USD", precio_dolar: Decimal.new(1)})
    {:ok, _} = Ledger.Moneda.changeset(:crear_moneda, %{nombre: "JAM", precio_dolar: Decimal.new(2)})
    {:ok, _} = Ledger.Moneda.changeset(:crear_moneda, %{nombre: "EUR", precio_dolar: Decimal.new(3)})


    usuarios = [
      Ledger.Repo.get_by!(Ledger.Usuario, username: "Gabriel"),
      Ledger.Repo.get_by!(Ledger.Usuario, username: "Heinly"),
      Ledger.Repo.get_by!(Ledger.Usuario, username: "Jordan")
    ]

    monedas = [
      Ledger.Repo.get_by!(Ledger.Moneda, nombre: "USD"),
      Ledger.Repo.get_by!(Ledger.Moneda, nombre: "JAM"),
      Ledger.Repo.get_by!(Ledger.Moneda, nombre: "EUR")
    ]

    {:ok, usuarios: usuarios, monedas: monedas}
  end

  test "Se muestra por pantalla informacion" do
    headers = [:id, :nombre, :apellido]
    data = [
      %{id: 1, nombre: "Gabriel", apellido: "Narváez"},
      %{id: 2, nombre: "Heinly", apellido: "Marín"},
      %{id: 3, nombre: "Jordan", apellido: "Carrillo"}
    ]

    res = Herramientas.mostrar_por_pantalla(headers, data)

    assert res == {:ok, "Operación realizada con exito"}
  end

  test "Query de balblabla", %{usuarios: usuarios, monedas: monedas} do
    assert not Herramientas.query_dada_alta?(Enum.at(usuarios, 0).id, Enum.at(monedas, 0).id)
  end

  test "Query true", %{usuarios: usuarios, monedas: monedas} do
    Ledger.Transaccion.changeset(:alta_cuenta, %{cuenta_origen_id: Enum.at(usuarios, 0).id, moneda_origen_id: Enum.at(monedas, 0).id})

    assert Herramientas.query_dada_alta?(Enum.at(usuarios, 0).id, Enum.at(monedas, 0).id)
  end

end
