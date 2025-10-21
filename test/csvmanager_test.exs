defmodule CSVManagerTest do
  use ExUnit.Case

  alias Estructuras.{Moneda, Transaccion}
  alias CSVManager

  @input_ok "data/"
  @test_dir "test/data/"


  test "Se lee un archivo bien escrito moneda" do
    res = CSVManager.readFileCSV(@input_ok <> "monedas.csv", Moneda, true)

    assert is_list(res)
  end

  test "Se lee un archivo mal escrito moneda" do
    res = CSVManager.readFileCSV(@test_dir <> "monedasMal.csv", Moneda, true)

    assert res == {:error, 3}
  end

  test "Se lee un archivo bien escrito transaccion" do
    res = CSVManager.readFileCSV(@input_ok <> "transacciones.csv", Transaccion, true)

    assert is_list(res)
  end

  test "Se lee un archivo mal escrito transaccion" do
    res = CSVManager.readFileCSV(@test_dir <> "transaccionesMal.csv", Transaccion, true)

    assert res == {:error, 5}
  end

  test "Se escribe un archivo punto y coma" do
    data = CSVManager.readFileCSV(@input_ok <> "monedas.csv", Moneda, true)

    res = CSVManager.writeFileCSV("testRes.csv", data, Moneda, true)

    assert res == {:ok, "Operación realizada con exito"}
  end

  test "Se escribe un archivo igual" do
    data = CSVManager.readFileCSV(@input_ok <> "monedas.csv", Moneda, true)

    res = CSVManager.writeFileCSV("testRes.csv", data, Moneda, false)

    assert res == {:ok, "Operación realizada con exito"}
  end

  test "Se lee un archivo moneda con = como separador" do
    res = CSVManager.readFileCSV(@test_dir <> "monedasIgual.csv", Moneda, false)

    assert is_list(res)
  end

end
