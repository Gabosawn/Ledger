defmodule CSVManagerTest do
    alias Estructuras.Moneda, as: Moneda
    alias Estructuras.Balance, as: Balance
    alias Estructuras.Argumentos, as: Argumentos
    alias Estructuras.Transaccion, as: Transaccion
    use ExUnit.Case
    doctest CSVManager

    test "Se lee el un archivo mal hecho de transaccion" do
        res = CSVManager.readFileCSV("test/transaccionesMal.csv", Transaccion, true)
        
        assert res == {:error, 5}
    end
    test "Se lee el un archivo mal hecho de monedas" do
        res = CSVManager.readFileCSV("test/monedasMal.csv", Moneda, true)
        
        assert res == {:error, 3}
    end

    test "Se escribe un archivo balance con 6 decimales" do
        Ledger.initOperation(%Argumentos{cuenta_origen: "userA", archivo_output: "pruebaDecimales.csv"}, "balance")
        res = CSVManager.readFileCSV("responsesFIles/pruebaDecimales.csv", Balance, false)
        |> Enum.map(fn balance ->
            map = Map.from_struct(balance)
            [_, x] = String.split(map[:BALANCE], ".")
            x
        end)|> Enum.all?(fn balance -> 
            String.length(balance) == 6
        end)

        assert res
    end

end