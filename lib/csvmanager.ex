defmodule CSVManager do
    @moduledoc """
    Módulo para manejar operaciones de lectura y escritura de archivos CSV,
    convirtiendo los datos a structs definidos por el usuario.

    Funciones principales:
        - `readFileCSV/3` : Lee un archivo CSV y convierte cada fila en un struct.
        - `writeFileCSV/4`: Escribe una lista de structs en un archivo CSV.
    """

    alias Estructuras.Balance, as: Balance

    # Carpeta donde se guardan los archivos de salida
    @responsesDir File.cwd!() <> "/responsesFIles/"

    @doc """
    Lee un archivo CSV y convierte cada fila en un struct del tipo `typeData`.

    ## Parámetros
        - `ruta` : Ruta del archivo CSV a leer (string).
        - `typeData` : Módulo del struct destino. Debe implementar `getHeaders/0`
        que devuelve la lista de encabezados esperados.
        - `puntoComa` : Booleano que indica si el separador es `;` (`true`) o `=` (`false`).

    ## Retorno
        - Lista de structs de tipo `typeData` si todo es correcto.
        - Lista parcial de structs válidos si hay errores (los errores se reportan en consola).

    ## Ejemplo
        CSVManager.readFileCSV("transacciones.csv", Transaccion, true)
    """
    def readFileCSV(ruta, typeData, puntoComa) do
        data =
        File.stream!(ruta)
        |> CSV.decode!(separator: (if puntoComa, do: ?;, else: ?=), headers: typeData.getHeaders)
        |> Enum.drop(1) # Ignorar encabezado
        |> Enum.with_index(2) # Para reportar línea de error
        |> Enum.map(fn dato ->
            x = length(Map.values(elem(dato, 0)))
            y = length(typeData.getHeaders)

            if x != y do
                {:error, elem(dato, 1)}
            else
                struct!(typeData, elem(dato, 0))
            end
        end)

        # Retorna el primer error encontrado o toda la lista de structs
        if Enum.any?(data, fn transaccion -> not is_struct(transaccion, typeData) end) do 
            Enum.find(data, fn transaccion -> not is_struct(transaccion, typeData) end)
        else
            data
        end
    end

    @doc """
    Escribe una lista de structs en un archivo CSV.

    ## Parámetros
        - `nombre` : Nombre del archivo a crear (string).
        - `data` : Lista de structs que se convertirán en filas CSV.
        - `typeData` : Módulo del struct, usado para obtener los encabezados mediante `getHeaders/0`.
        - `puntoComa` : Booleano que indica si el separador es `;` (`true`) o `=` (`false`).

    ## Retorno
        - `:ok` cuando finaliza exitosamente.

    ## Ejemplo
        CSVManager.writeFileCSV("salida.csv", lista_transacciones, Transaccion, true)
    """
    def writeFileCSV(nombre, data, typeData, puntoComa) do 
        file = File.open!(@responsesDir <> nombre, [:write, :utf8])
        Enum.map(data, fn transaccion -> 
            map = Map.from_struct(transaccion)
            cond do 
                typeData == Balance ->
                Map.update!(map, :BALANCE, fn balance ->
                    if is_float(balance) do
                        Float.to_string(balance, decimals: 6)
                    else
                        balance
                    end
                end)
                true -> map
            end
        end)
        |> CSV.encode(headers: typeData.getHeaders, separator: (if puntoComa, do: ?;, else: ?=))
        |> Enum.each(fn linea -> IO.write(file, linea) end)

        :ok
    end
end
