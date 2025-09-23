defmodule Balance do
    @moduledoc """
    Proporciona funciones para calcular balances de cuentas en diferentes divisas
    a partir de transacciones y precios de monedas.

    Flujo típico:
        1. Se toman transacciones y la lista de divisas con sus precios en USD.
        2. Se convierten montos entre monedas según sea necesario.
        3. Se calcula el balance por cada divisa asociada a una cuenta.

    Función principal:
        - `porMoneda/4` : Calcula el balance de una cuenta por moneda o en una sola moneda.
    """

    alias Estructuras.Balance, as: Bal

    @doc false
    # Convierte un monto de una moneda a otra usando precios en USD
    defp cambioDe(origen, destino, monto, listaDivisas) do
        origenDolar = Enum.find(listaDivisas, fn divisa ->
            divisa.nombre_moneda == origen
        end) |> Map.get(:precio_usd)
        |> String.to_float

        destinoDolar = Enum.find(listaDivisas, fn divisa ->
            divisa.nombre_moneda == destino
        end) |> Map.get(:precio_usd)
        |> String.to_float

        %{MONEDA: destino, BALANCE: ((origenDolar * monto) / destinoDolar) |> Float.round(6)}
    end

    @doc false
    # Calcula el balance de una transacción para una cuenta específica
    defp balanceTransaccion(cuenta, transaccion, listaDivisas) do
        cond do 
            cuenta == transaccion.cuenta_origen ->
                %{MONEDA: transaccion.moneda_origen,
                BALANCE: String.to_float(transaccion.monto) * -1 |> Float.round(6)}
            cuenta == transaccion.cuenta_destino ->
                cambioDe(transaccion.moneda_origen, transaccion.moneda_destino, String.to_float(transaccion.monto), listaDivisas)
        end
    end

    @doc false
    # Calcula balance de un swap (intercambio) entre monedas
    defp balanceSwap(transaccion, listaDivisas) do 
        desde = %{MONEDA: transaccion.moneda_origen, BALANCE: String.to_float(transaccion.monto) * -1 |> Float.round(6)}
        hacia = cambioDe(transaccion.moneda_origen, transaccion.moneda_destino, String.to_float(transaccion.monto), listaDivisas)
        [desde, hacia]
    end

    @doc false
    # Busca errores representados como tuplas en balances
    defp takeError(balance) do
        Enum.find(balance, fn bal -> is_tuple(bal) end)
    end

    @doc false
    # Calcula balances de todas las transacciones de una cuenta
    defp listBalanceTodasMoneda(listaTransacciones, cuenta, listaDivisas) do 
        Enum.map(listaTransacciones, fn transaccion ->
            case transaccion.tipo do
                "alta_cuenta" ->
                    %{MONEDA: transaccion.moneda_origen, BALANCE: String.to_float(transaccion.monto) |> Float.round(6)}
                "transferencia" ->
                    balanceTransaccion(cuenta, transaccion, listaDivisas)
                "swap" ->
                    balanceSwap(transaccion, listaDivisas)
                _ ->
                    linea = String.to_integer(transaccion.id_transaccion) + 1
                    {:error, "El tipo de transaccion no se encuentra descrito en la linea " <> Integer.to_string(linea)}
            end
        end)
        |> List.flatten()
    end

    @doc false
    # Agrupa balances por moneda, sumando los balances de la misma moneda
    defp uniqDeCadaMoneda(balance) do 
        cond do
            takeError(balance) != nil -> takeError(balance)
            true -> 
                Enum.reduce(balance, [], fn bal, acc ->
                    cond do
                        acc == [] ->
                            acc ++ [bal]
                            Enum.any?(acc, fn a -> a[:MONEDA] == bal[:MONEDA] end) ->
                            Enum.map(acc, fn a ->
                                if a[:MONEDA] == bal[:MONEDA] do
                                    %{a | BALANCE: bal[:BALANCE] + a[:BALANCE]}
                                else
                                    a
                                end
                            end)
                        true -> acc ++ [bal]
                    end  
                end)
        end
    end

    @doc false
    # Verifica si algún balance es negativo
    defp valoresNegativos?(balance) do 
        Enum.any?(balance, fn bal -> bal[:BALANCE] < 0.0 end)
    end

    @doc false
    # Convierte todos los balances a una sola moneda y los suma
    defp balanceUnaSolaMoneda(balance, moneda, listaDivisas) do 
        Enum.map(balance, fn bal ->
            cambioDe(bal[:MONEDA], moneda, bal[:BALANCE], listaDivisas)
        end) |> Enum.reduce(%{}, fn bal, acc ->
            if acc == %{} do
                bal
            else
                %{acc | BALANCE: bal[:BALANCE] + acc[:BALANCE]}
            end
        end)
    end

    @doc """
    Calcula el balance de una cuenta.

    ## Parámetros
        - `listaTransacciones`: Lista de transacciones.
        - `cuenta`: Nombre de la cuenta a calcular.
        - `listaDivisas`: Lista de divisas con precios en USD.
        - `moneda`: (Opcional) Si se indica, convierte todo a esta moneda.

    ## Retorna
        - Lista de structs `%Bal{}` por cada moneda si `moneda` es `nil`.
        - Struct `%Bal{}` con balance en la moneda indicada si `moneda` está definido.
        - `{:error, mensaje}` si ocurre algún error o hay valores negativos.
    """
    def porMoneda(listaTransacciones, cuenta, listaDivisas, moneda) do
        balance = listBalanceTodasMoneda(listaTransacciones, cuenta, listaDivisas)
        |> uniqDeCadaMoneda()

        if is_tuple(balance) do
            balance
        else
            cond do 
                valoresNegativos?(balance) -> {:error, "Los valores en el balance de la cuenta " <> cuenta <> " son negativos"}
                moneda == nil -> Enum.map(balance, fn bal -> struct!(Bal, bal) end)
                true -> struct!(Bal, balanceUnaSolaMoneda(balance, moneda, listaDivisas))
            end
        end
    end
end
