defmodule CSVManager do
  @moduledoc """
  Módulo para gestionar operaciones de lectura y escritura de archivos CSV.

  Proporciona funcionalidades para convertir datos entre archivos CSV y estructuras
  de Elixir (structs), facilitando la importación y exportación de datos en el
  sistema Ledger.

  ## Funcionalidades principales

  - **Lectura de CSV**: Lee archivos CSV y convierte cada fila en un struct
  - **Escritura de CSV**: Convierte structs a formato CSV y los escribe en archivos
  - **Validación de estructura**: Verifica que las filas tengan el número correcto de columnas
  - **Formato de Balance**: Manejo especial de números decimales para balances

  ## Separadores soportados

  - Punto y coma (`;`) - Estándar europeo
  - Igual (`=`) - Formato personalizado

  ## Directorio de salida

  Los archivos de salida se guardan en: `#{File.cwd!()}/responsesFiles/`

  ## Validación automática

  - Verifica que cada fila tenga el número correcto de columnas
  - Detecta y reporta errores de formato (número de línea)
  - Salta automáticamente la primera fila (encabezados)

  ## Formato especial para Balances

  Los balances se formatean con 6 decimales de precisión para mantener
  consistencia en cálculos financieros.

  ## Ejemplos

      # Leer transacciones desde CSV
      CSVManager.readFileCSV("data/transacciones.csv", Estructuras.Transaccion, true)

      # Escribir balances a CSV
      CSVManager.writeFileCSV("balance_output.csv", lista_balances, Estructuras.Balance, true)

      # Leer con separador personalizado
      CSVManager.readFileCSV("custom.csv", MiStruct, false)
  """

  alias Estructuras.Balance, as: Balance

  # Carpeta donde se guardan los archivos de salida
  @responsesDir File.cwd!() <> "/responsesFiles/"

  @doc """
  Lee un archivo CSV y convierte cada fila en un struct del tipo especificado.

  Esta función procesa archivos CSV línea por línea, validando la estructura
  y convirtiendo cada fila válida en un struct. Detecta errores de formato
  y los reporta con el número de línea.

  ## Parámetros

  - `ruta` - Ruta del archivo CSV a leer (string). Puede ser relativa o absoluta.
  - `typeData` - Módulo del struct destino. Debe implementar `getHeaders/0` que
    devuelve la lista de encabezados (campos) esperados.
  - `puntoComa` - Booleano que indica el separador:
    - `true` - Usa punto y coma (`;`) como separador
    - `false` - Usa igual (`=`) como separador

  ## Proceso

  1. Abre el archivo como stream
  2. Decodifica usando el separador especificado
  3. Ignora la primera línea (encabezados)
  4. Enumera las líneas con índice (empezando en 2)
  5. Valida que cada línea tenga el número correcto de columnas
  6. Convierte filas válidas a structs
  7. Retorna lista completa o primer error encontrado

  ## Retorna

  - Lista de structs de tipo `typeData` si todo es correcto
  - `{:error, numero_linea}` si se encuentra un error de formato

  ## Validación

  Verifica que cada fila tenga exactamente el mismo número de columnas que
  los encabezados definidos en `typeData.getHeaders()`.

  ## Ejemplos

      # Leer transacciones (separador ;)
      iex> CSVManager.readFileCSV("transacciones.csv", Estructuras.Transaccion, true)
      [
        %Estructuras.Transaccion{id_transaccion: 1, ...},
        %Estructuras.Transaccion{id_transaccion: 2, ...}
      ]

      # Error de formato en línea 5
      iex> CSVManager.readFileCSV("malformado.csv", Estructuras.Balance, true)
      {:error, 5}

      # Archivo vacío (solo encabezados)
      iex> CSVManager.readFileCSV("vacio.csv", Estructuras.Moneda, true)
      []

      # Leer con separador personalizado
      iex> CSVManager.readFileCSV("custom.csv", MiStruct, false)
      [%MiStruct{...}]
  """
  def readFileCSV(ruta, typeData, puntoComa) do
    data =
      File.stream!(ruta)
      |> CSV.decode!(separator: if(puntoComa, do: ?;, else: ?=), headers: typeData.getHeaders())
      # Ignorar encabezado
      |> Enum.drop(1)
      # Para reportar línea de error
      |> Enum.with_index(2)
      |> Enum.map(fn dato ->
        x = length(Map.values(elem(dato, 0)))
        y = length(typeData.getHeaders())

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

  Esta función convierte structs de Elixir a formato CSV y los escribe en un
  archivo, incluyendo encabezados automáticamente. Maneja formatos especiales
  para ciertos tipos de datos (como Balances con precisión decimal).

  ## Parámetros

  - `nombre` - Nombre del archivo a crear (string). No incluir la ruta, se
    guardará automáticamente en el directorio `responsesFiles/`.
  - `data` - Lista de structs que se convertirán en filas CSV. Todos deben
    ser del mismo tipo especificado en `typeData`.
  - `typeData` - Módulo del struct, usado para obtener los encabezados mediante
    `getHeaders/0` y para determinar el formato de salida.
  - `puntoComa` - Booleano que indica el separador:
    - `true` - Usa punto y coma (`;`) como separador
    - `false` - Usa igual (`=`) como separador

  ## Proceso

  1. Abre/crea el archivo en modo escritura con encoding UTF-8
  2. Convierte cada struct a mapa
  3. Aplica formato especial si es tipo Balance (6 decimales)
  4. Codifica a formato CSV con encabezados
  5. Escribe cada línea al archivo
  6. Cierra el archivo

  ## Formato especial de Balance

  Para structs de tipo `Estructuras.Balance`, el campo `BALANCE` se formatea
  con exactamente 6 decimales para mantener precisión en cálculos financieros.

  ## Ubicación de archivos

  Los archivos se guardan en: `#{File.cwd!()}/responsesFiles/nombre`

  ## Retorna

  `{:ok, "Operación realizada con exito"}` cuando finaliza exitosamente

  ## Ejemplos

      # Escribir balances
      iex> balances = [
      ...>   %Estructuras.Balance{MONEDA: "USD", BALANCE: 1500.123456},
      ...>   %Estructuras.Balance{MONEDA: "EUR", BALANCE: 750.5}
      ...> ]
      iex> CSVManager.writeFileCSV("balance.csv", balances, Estructuras.Balance, true)
      {:ok, "Operación realizada con exito"}
      # Crea archivo: responsesFiles/balance.csv con separador ;

      # Escribir transacciones
      iex> transacciones = [%Estructuras.Transaccion{...}]
      iex> CSVManager.writeFileCSV("trans_output.csv", transacciones, Estructuras.Transaccion, true)
      {:ok, "Operación realizada con exito"}

      # Con separador personalizado
      iex> CSVManager.writeFileCSV("custom.csv", data, MiStruct, false)
      {:ok, "Operación realizada con exito"}
      # Crea archivo con separador =

      # Archivo generado (ejemplo para Balance):
      # MONEDA;BALANCE
      # USD;1500.123456
      # EUR;750.500000
  """
  def writeFileCSV(nombre, data, typeData, puntoComa) do
    file = File.open!(@responsesDir <> nombre, [:write, :utf8])

    Enum.map(data, fn transaccion ->
      map = Map.from_struct(transaccion)

      cond do
        typeData == Balance ->
          Map.update!(map, :BALANCE, fn balance ->
            if is_float(balance) do
              :erlang.float_to_binary(balance, decimals: 6)
            else
              balance
            end
          end)

        true ->
          map
      end
    end)
    |> CSV.encode(headers: typeData.getHeaders(), separator: if(puntoComa, do: ?;, else: ?=))
    |> Enum.each(fn linea -> IO.write(file, linea) end)
    File.close(file)

    {:ok, "Operación realizada con exito"}
  end
end
