defmodule LedgerTest do
  alias Estructuras.Argumentos, as: Argumentos
  alias Estructuras.Transaccion, as: Transaccion
  alias Estructuras.Balance, as: Balance
  alias CSVManager

  use ExUnit.Case
  doctest Ledger

  test "Inicia operacion transaccion sin flags con el archivo default bien hecho" do
    res = Ledger.initOperation(%Argumentos{}, "transacciones")
    expected = CSVManager.readFileCSV("data/transacciones.csv", Transaccion, true)
    
    assert length(res) == length(expected) 
    assert is_list(res)
    assert res == expected
  end

  test "La operacion transacciones tiene el flag moneda" do
    res = Ledger.initOperation(%Argumentos{moneda: "USDT"}, "transacciones")

    assert length(res) == 4
    assert is_list(res)
  end

  test "La operacion transacciones tiene el flag moneda, cuenta origen, cuenta destino" do
    res = Ledger.initOperation(%Argumentos{moneda: "USDT", cuenta_origen: "userA", cuenta_destino: "userB"}, "transacciones")

    assert length(res) == 1
    assert is_list(res)
  end

  test "La operacion transacciones tiene el flag archivo output" do
    res = Ledger.initOperation(%Argumentos{archivo_output: "pruebaT.csv"}, "transacciones")
    resArch = CSVManager.readFileCSV("responsesFIles/pruebaT.csv", Transaccion, true)
    
    expected = CSVManager.readFileCSV("data/transacciones.csv", Transaccion, true)
    

    assert res == :ok
    assert resArch == expected
  end

  test "La operacion balance se hace con un archivo con todas los datos completos" do
    res = Ledger.initOperation(%Argumentos{cuenta_origen: "userA"}, "balance")

    assert length(res) == 3
    assert is_list(res)
  end

  test "La operacion balance se hace con un archivo con todas los datos completos y una moneda" do 
    res = Ledger.initOperation(%Argumentos{cuenta_origen: "userA", moneda: "SOL"}, "balance")

    assert is_struct(res)
  end

  test "La operacion balance tiene un archivo con datos incompleots tipo" do
    res = Ledger.initOperation(%Argumentos{cuenta_origen: "userA", archivo_input: "test/transaccionesTipo.csv", moneda: "SOL"}, "balance")

    assert is_tuple(res)
    assert res == {:error, "El tipo de transaccion no se encuentra descrito en la linea 3"}
  end

  test "La operacion balance tiene un balance negativo" do
    res = Ledger.initOperation(%Argumentos{cuenta_origen: "userA", archivo_input: "test/transaccionesNegativo.csv", moneda: "SOL"}, "balance")

    assert is_tuple(res)
    assert res == {:error, "Los valores en el balance de la cuenta userA son negativos"}
  end

  test "La operacion balance se guarda en un archivo csv" do
    res = Ledger.initOperation(%Argumentos{cuenta_origen: "userA", archivo_output: "pruebaB.csv"}, "balance")

    assert res == :ok
  end
end
