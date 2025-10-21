defmodule Operaciones.ArgumentosTest do
  use ExUnit.Case
  alias Estructuras.Argumentos, as: Argumentos
  alias Ledger.{Moneda, Usuario, Transaccion, Repo}

  setup do
    # Configurar el sandbox para cada test
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)

    Moneda.changeset(:crear_moneda, %{nombre: "EUR", precio_dolar: 2})
    Moneda.changeset(:crear_moneda, %{nombre: "USD", precio_dolar: 1})
    Usuario.changeset(:crear_usuario, %{username: "Gabriel", nacimiento: "2003-07-14"})
    Usuario.changeset(:crear_usuario, %{username: "Alejandro", nacimiento: "2000-12-12"})

    moneda_eur = Repo.get_by!(Moneda, nombre: "EUR")
    moneda_usd = Repo.get_by!(Moneda, nombre: "USD")
    usuario_ga = Repo.get_by!(Usuario, username: "Gabriel")
    usuario_al = Repo.get_by!(Usuario, username: "Alejandro")

    Transaccion.changeset(:alta_cuenta, %{cuenta_origen_id: usuario_ga.id, moneda_origen_id: moneda_usd.id, monto: 100})
    Transaccion.changeset(:alta_cuenta, %{cuenta_origen_id: usuario_al.id, moneda_origen_id: moneda_eur.id, monto: 100})
    Transaccion.changeset(:realizar_swap, %{cuenta_origen_id: usuario_ga.id, moneda_origen_id: moneda_usd.id, moneda_destino_id: moneda_eur.id, monto: 50})
    Transaccion.changeset(:realizar_transferencia, %{cuenta_origen_id: usuario_ga.id, moneda_origen_id: moneda_usd.id, cuenta_destino_id: usuario_al.id, monto: 25})
    Transaccion.changeset(:realizar_transferencia, %{cuenta_origen_id: usuario_al.id, moneda_origen_id: moneda_eur.id, cuenta_destino_id: usuario_ga.id, monto: 50})

    :ok
  end

  test "Ok, transacciones no csv" do
    res = Argumentos.changeset(:transacciones, %{})

    assert res == {:ok, "Operación realizada con exito"}
  end

  test "Ok, transacciones si csv" do
    res = Argumentos.changeset(:transacciones, %{archivo_input: "data/transacciones.csv"})

    assert res == {:ok, "Operación realizada con exito"}
  end

  test "Ok, balance no csv" do
    res = Argumentos.changeset(:balance, %{cuenta_origen: "Gabriel"})

    assert res == {:ok, "Operación realizada con exito"}
  end

  test "Ok, balance si csv" do
    res = Argumentos.changeset(:balance, %{cuenta_origen: "Gabriel", archivo_input: "data/transacciones.csv"})

    assert res == {:ok, "Operación realizada con exito"}
  end

  test "Ok, balance se guarda en csv" do
    res = Argumentos.changeset(:balance, %{cuenta_origen: "Gabriel", archivo_output: "balanceSalida.csv"})

    assert res == {:ok, "Operación realizada con exito"}
  end

  test "Ok, transacciones se guarda en csv" do
    res = Argumentos.changeset(:transacciones, %{cuenta_origen: "Gabriel", archivo_output: "transaccionesSalida.csv"})

    assert res == {:ok, "Operación realizada con exito"}
  end

  test "Ok, balance en una sola moneda" do
    res = Argumentos.changeset(:balance, %{cuenta_origen: "Gabriel", moneda: "USD"})

    assert res == {:ok, "Operación realizada con exito"}
  end

  test "Error, balance se encuentran balances negativos" do
    res = Argumentos.changeset(:balance, %{cuenta_origen: "Gabriel", archivo_input: "test/data/transaccionesNegativo.csv"})

    assert res == {:error, balance: "Las transacciones de la cuenta Gabriel tienen balances negativos"}
  end

  test "Error, balance falta el flag cuenta origen" do
    res = Argumentos.changeset(:balance, %{})

    assert res == {:error, balance: "EL flag -c1 es obligatorio"}
  end

  test "Error, balance nombre moneda muy corto o muy largo" do
    res = Argumentos.changeset(:balance, %{cuenta_origen: "Gabriel", moneda: "EU"})

    assert res == {:error, balance: "El nombre de la moneda debe ser de 3 o 4 letras"}
  end

  test "Error, balance nombre moneda en minusculas" do
    res = Argumentos.changeset(:balance, %{cuenta_origen: "Gabriel", moneda: "eur"})

    assert res == {:error, balance: "El nombre de la moneda debe estar completamente en mayúsculas"}
  end

  test "Error, balance flag cuenta destino no permitido" do
    res = Argumentos.changeset(:balance, %{cuenta_origen: "Gabriel", cuenta_destino: "Alejandro"})

    assert res == {:error, balance: "En la operacion de balance el flag -c2 no esta permitido"}
  end

  test "Error, balance no encontro ningun dato" do
    res = Argumentos.changeset(:balance, %{cuenta_origen: "NoExiste"})

    assert res == {:error, balance: "No existen transacciones"}
  end

  test "Error, transacciones no encontro ningun dato" do
    res = Argumentos.changeset(:transacciones, %{cuenta_origen: "NoExiste"})

    assert res == {:error, transacciones: "No existen transacciones que mostrar"}
  end
end
