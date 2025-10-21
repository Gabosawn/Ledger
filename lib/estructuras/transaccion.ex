defmodule Estructuras.Transaccion do
  @moduledoc """
  Módulo para gestionar transacciones en el sistema Ledger.

  Este módulo proporciona funcionalidades para:
  - Definir la estructura de datos de una transacción
  - Consultar y filtrar transacciones desde archivos CSV o base de datos
  - Procesar operaciones de listado de transacciones

  ## Estructura de datos

  Cada transacción contiene:
  - `id_transaccion` - Identificador único de la transacción
  - `timestamp` - Fecha y hora de la transacción
  - `moneda_origen` - Código de la moneda de origen
  - `moneda_destino` - Código de la moneda de destino (para swaps)
  - `monto` - Cantidad de la transacción
  - `cuenta_origen` - Identificador de la cuenta origen
  - `cuenta_destino` - Identificador de la cuenta destino
  - `tipo` - Tipo de transacción: "alta_cuenta", "transferencia" o "swap"

  ## Tipos de transacciones

  - **alta_cuenta**: Apertura de cuenta con depósito inicial
  - **transferencia**: Transferencia de fondos entre dos cuentas
  - **swap**: Intercambio de una moneda por otra dentro de la misma cuenta

  ## Ejemplos

      # Obtener todas las transacciones de una cuenta
      iex> Estructuras.Transaccion.obtenerTransacciones("cuenta_123", "cuenta_123", nil, nil)
      [%Estructuras.Transaccion{...}]

      # Filtrar por moneda específica
      iex> Estructuras.Transaccion.obtenerTransacciones(nil, nil, "USD", "transacciones.csv")
      [%Estructuras.Transaccion{moneda_origen: "USD", ...}]
  """

  import Ecto.Changeset

  @headers [:id_transaccion, :timestamp, :moneda_origen, :moneda_destino, :monto, :cuenta_origen, :cuenta_destino, :tipo]
  defstruct @headers

  @doc """
  Retorna los headers (campos) disponibles para la estructura de transacción.

  ## Retorna

  Una lista con los átomos que representan los campos de la estructura:
  - `:id_transaccion` - ID único
  - `:timestamp` - Fecha/hora
  - `:moneda_origen` - Moneda de origen
  - `:moneda_destino` - Moneda de destino
  - `:monto` - Cantidad
  - `:cuenta_origen` - Cuenta origen
  - `:cuenta_destino` - Cuenta destino
  - `:tipo` - Tipo de transacción

  ## Ejemplos

      iex> Estructuras.Transaccion.getHeaders()
      [:id_transaccion, :timestamp, :moneda_origen, :moneda_destino, :monto, :cuenta_origen, :cuenta_destino, :tipo]
  """
  def getHeaders do
    @headers
  end

  @doc """
  Obtiene y filtra transacciones según los criterios especificados.

  Esta función consulta transacciones desde la base de datos o desde un archivo CSV,
  aplicando filtros por cuenta origen, cuenta destino y moneda según los parámetros
  proporcionados.

  ## Parámetros

  - `origen` - Identificador de la cuenta origen para filtrar. Si es `nil`, no filtra por origen
  - `destino` - Identificador de la cuenta destino para filtrar. Si es `nil`, no filtra por destino
  - `moneda` - Código de moneda para filtrar. Si es `nil`, no filtra por moneda
  - `ruta` - Ruta del archivo CSV con transacciones. Si es `nil`, consulta la base de datos

  ## Comportamiento de filtrado

  - **origen == destino**: Filtra transacciones donde la cuenta aparece como origen O destino
  - **origen != destino**: Filtra transacciones con origen Y destino específicos
  - **moneda**: Filtra por moneda_origen O moneda_destino

  ## Retorna

  Lista de estructuras `%Estructuras.Transaccion{}` que cumplen los criterios de filtrado.
  Retorna lista vacía `[]` si no hay coincidencias.

  ## Ejemplos

      # Todas las transacciones de una cuenta (origen == destino)
      iex> obtenerTransacciones("cuenta_123", "cuenta_123", nil, nil)
      [%Estructuras.Transaccion{cuenta_origen: "cuenta_123", ...}, ...]

      # Transferencias desde origen a destino específico
      iex> obtenerTransacciones("cuenta_A", "cuenta_B", nil, "data.csv")
      [%Estructuras.Transaccion{cuenta_origen: "cuenta_A", cuenta_destino: "cuenta_B", ...}]

      # Filtrar por moneda USD
      iex> obtenerTransacciones(nil, nil, "USD", "data.csv")
      [%Estructuras.Transaccion{moneda_origen: "USD", ...}, ...]

      # Sin coincidencias
      iex> obtenerTransacciones("cuenta_inexistente", "cuenta_inexistente", nil, nil)
      []
  """
  def obtenerTransacciones(origen, destino, moneda, ruta) do
    cond do
      ruta == nil -> Herramientas.query_transacciones(origen, destino, moneda)
      ruta != nil ->
        CSVManager.readFileCSV(ruta, Estructuras.Transaccion, true)
        |> Enum.filter(fn transaccion ->
          if origen == destino do
            cond do
              origen == nil -> true
              true -> transaccion.cuenta_origen == origen or transaccion.cuenta_destino == origen
            end
          else
            cond do
              origen == nil and destino == nil -> true
              origen != nil and destino != nil -> transaccion.cuenta_origen == origen and transaccion.cuenta_destino == origen
              origen == nil and destino != nil -> transaccion.cuenta_destino == destino
              origen != nil and destino == nil -> transaccion.cuenta_origen == origen
            end
          end
        end)
        |> Enum.filter(fn transaccion ->
          if moneda == nil, do: true, else: transaccion.moneda_origen == moneda or transaccion.moneda_destino == moneda
        end)
    end
  end

  @doc """
  Inicializa y ejecuta una operación de consulta de transacciones.

  Esta función es el punto de entrada principal para las operaciones de listado de
  transacciones. Obtiene los parámetros del changeset, consulta las transacciones
  según los filtros especificados y genera el archivo de salida.

  ## Proceso

  1. Extrae parámetros del changeset (archivo entrada, cuentas, moneda, salida)
  2. Obtiene las transacciones filtradas según los criterios
  3. Valida que existan transacciones que mostrar
  4. Genera el archivo de salida con los resultados

  ## Parámetros

  - `changeset` - Changeset de Ecto con los campos:
    - `:archivo_input` - Ruta del archivo de transacciones CSV (opcional)
    - `:cuenta_origen` - Identificador de la cuenta origen para filtrar (opcional)
    - `:cuenta_destino` - Identificador de la cuenta destino para filtrar (opcional)
    - `:moneda` - Código de moneda para filtrar (opcional)
    - `:archivo_output` - Ruta del archivo de salida (opcional)

  ## Retorna

  - `{:ok, resultado}` - Si la operación fue exitosa y se generó el archivo
  - `{:error, Ecto.Changeset.t()}` - Si no hay transacciones, con el changeset actualizado

  ## Ejemplos

      # Listar transacciones de una cuenta
      iex> changeset = cast(%Estructuras.Argumentos{},
      ...>   %{cuenta_origen: "123", cuenta_destino: "123"},
      ...>   [:cuenta_origen, :cuenta_destino])
      iex> initOperation(changeset)
      {:ok, resultado}

      # Filtrar por moneda
      iex> changeset = cast(%Estructuras.Argumentos{},
      ...>   %{moneda: "USD", archivo_input: "data.csv"},
      ...>   [:moneda, :archivo_input])
      iex> initOperation(changeset)
      {:ok, resultado}

      # Sin transacciones encontradas
      iex> changeset = cast(%Estructuras.Argumentos{},
      ...>   %{cuenta_origen: "cuenta_sin_movimientos"},
      ...>   [:cuenta_origen])
      iex> initOperation(changeset)
      {:error, %Ecto.Changeset{errors: [transacciones: {"No existen transacciones que mostrar", _}]}}
  """
  def initOperation(changeset) do
    input = get_field(changeset, :archivo_input)
    origen = get_field(changeset, :cuenta_origen)
    output = get_field(changeset, :archivo_output)
    destino = get_field(changeset, :cuenta_destino)
    moneda = get_field(changeset, :moneda)

    data = obtenerTransacciones(origen, destino, moneda, input)

    case data do
      [] -> {:error, add_error(changeset, :transacciones, "No existen transacciones que mostrar")}
      _ -> Ledger.finishOperation(data, output, Estructuras.Transaccion, true)
    end
  end
end
