defmodule Argumentos do
    @moduledoc """
    Módulo para validar y procesar los argumentos de línea de comando
    para operaciones financieras. Permite validar flags, verificar 
    duplicados, valores faltantes y finalmente ejecutar operaciones
    de `balance` o `transacciones` usando el módulo `Ledger`.

    Flags disponibles:
        - `-c1` : cuenta origen
        - `-c2` : cuenta destino
        - `-t`  : archivo de input
        - `-m`  : moneda
        - `-o`  : archivo de output
    """

    alias Estructuras.Argumentos, as: Args
    alias Ledger    

    @origen "-c1"
    @destino "-c2"
    @input "-t"
    @moneda "-m"
    @output "-o"
    @operaciones ["transacciones", "balance"]

    @doc """
    Valida los argumentos recibidos desde la línea de comando.

    - `args` es una lista de strings con los parámetros ingresados.
    Retorna:
        - `{:error, mensaje}` si hay algún error.
        - Llama a `Ledger.initOperation/2` si los argumentos son válidos.
    """
    def validationArgs(args) do 
        case args do
            x when hd(x) in @operaciones -> verifyFlags(tl(args), hd(args))
            [] -> {:error, "No se ha proporcionado ningun parámetro"}
            _ -> 
                coindicencia = Enum.find(@operaciones, fn operacion -> 
                String.jaro_distance(hd(args), operacion) > 0.7
                end)

                cond do 
                    coindicencia == nil -> {:error, "Escribir primero el tipo de operacion: balance  o transacciones"}
                    true -> {:error, "Quisiste decir " <> coindicencia}
                end
        end
    end

    @doc false
    # Verifica que los flags sean válidos para la operación especificada
    defp verifyFlags(flags, typeOperation) do
        valid = validFlags(flags)

        cond do 
            flags -- valid != [] -> {:error, "Flags invalidos. Los que se pueden usar son: -c1=origen -c2=destino -t=input -m=moneda -o=output"}
            flags == [] and typeOperation == "balance" -> {:error, "No se ha proporcionado ningun flag"}
            true -> verifyValidFlags(valid, typeOperation)
        end
    end

    @doc false
    # Valida flags duplicados y flags sin valor
    defp verifyValidFlags(validFlags, typeOperation) do
        keysValues = Enum.map(validFlags, fn arg -> String.split(arg, "=") end)

        cond do 
            argumentoDuplicado?(keysValues) -> {:error, "Algún flag se encuentra duplicado"}
            argumentoSinValor?(keysValues) -> 
                err = argumentoSinValor(keysValues) 
                {:error, "El flag " <> Enum.at(err, 0) <> " no tiene ningun valor"}
            true -> operation(keysValues, typeOperation)
        end
    end

    @doc false
    # Convierte los flags válidos en un struct y ejecuta la operación
    defp operation(keysValues, typeOperation) do 
        map = Enum.map(keysValues, fn arg ->
            case Enum.at(arg, 0) do
                @origen -> {:cuenta_origen, Enum.at(arg, 1)}
                @input -> {:archivo_input, Enum.at(arg, 1)}
                @moneda -> {:moneda, String.upcase(Enum.at(arg, 1))}
                @output -> {:archivo_output, Enum.at(arg, 1)}
                @destino -> {:cuenta_destino, Enum.at(arg, 1)}
            end
        end)

        flagsStruct = struct!(Args, map)

        cond do 
            flagsStruct.cuenta_origen == nil and typeOperation == "balance" -> {:error, "En la operacion de balance es obligatorio poner el flag -c1"}
            flagsStruct.cuenta_destino != nil and typeOperation == "balance" -> {:error, "En la operacion de balance el flag -c2 no esta permitido"}
            true -> Ledger.initOperation(flagsStruct, typeOperation)
        end
    end

    @doc false
    # Verifica si hay algún flag duplicado
    defp argumentoDuplicado?(args) do
        Enum.any?(args, fn arg -> 
            Enum.count(args, fn argumento -> hd(argumento) == hd(arg) end) > 1 
        end)
    end

    @doc false
    # Verifica si algún flag está sin valor
    defp argumentoSinValor?(args) do
        Enum.any?(args, fn arg -> tl(arg) == [] or tl(arg) == [""] end)
    end

    @doc false
    # Devuelve el primer flag que está sin valor
    defp argumentoSinValor(args) do
        Enum.find(args, fn arg -> tl(arg) == [] or tl(arg) == [""] end)
    end

    @doc false
    # Filtra los flags válidos según los definidos en el módulo
    defp validFlags(args) do
        Enum.filter(args, fn arg ->
            String.contains?(arg, @origen) or
            String.contains?(arg, @destino) or
            String.contains?(arg, @input) or
            String.contains?(arg, @moneda) or
            String.contains?(arg, @output)
        end)
    end
end
