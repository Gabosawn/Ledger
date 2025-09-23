defmodule Ledger do

  @moduledoc """
  Módulo principal para ejecutar operaciones sobre el sistema de registros financieros.

  Permite trabajar con dos operaciones principales:
    - **`transacciones`**: filtrar y obtener transacciones según ciertos criterios.
    - **`balance`**: calcular balances por cuenta y moneda, utilizando transacciones y monedas.

  Las operaciones leen por default desde archivos CSV (`transacciones.csv`, `monedas.csv`) o
  desde un archivo CSV proporcionado a través de los flags, y devuelven o imprimen los resultados
  según la configuración de los flags.
  """


  alias Estructuras.Moneda, as: Moneda
  alias Estructuras.Transaccion, as: Transaccion
  alias CSVManager
  alias Balance
  alias Estructuras.Balance, as: Bal


  # Archivos por defecto
  @transaccionesFile "data/transacciones.csv"
  @monedasFile "data/monedas.csv"


  @doc """
  Inicializa una operación sobre los datos.

  ## Parámetros
    - `flags`: struct con parámetros de entrada, salida y filtros.
      - `:archivo_input` (opcional): archivo de entrada CSV alternativo.
      - `:archivo_output` (opcional): archivo de salida CSV.
      - Otros campos serán considerados como filtros para las operaciones.
    - `typeOperation`: string que define el tipo de operación a ejecutar.
      - `"transacciones"` → procesa transacciones.
      - `"balance"` → calcula balance.

  ## Retorno
    - Depende de la operación:
      - Para `"transacciones"`, devuelve o escribe las transacciones filtradas.
      - Para `"balance"`, devuelve o escribe los balances por moneda.

  ## Ejemplo
      Ledger.initOperation(flags, "balance")
      Ledger.initOperation(flags, "transacciones")
  """
  def initOperation(flags, typeOperation) do
    flagsMap = Map.from_struct(flags)
    # Separar parámetros de entrada/salida del resto (que serán filtros)
    iO = Map.filter(flagsMap, fn {key, _} -> key == :archivo_input or key == :archivo_output end)
    filtros = Map.drop(flagsMap, Map.keys(iO))

    case typeOperation do
      "transacciones" ->
        transacciones(iO, filtros)
      "balance" ->
        balance(iO, filtros)
    end
  end


  @doc false
  # Calcula el balance de una cuenta según filtros y archivos CSV
  defp balance(iO, filters) do
    cuenta = filters.cuenta_origen
    moneda = filters.moneda
    listMonedas = CSVManager.readFileCSV(@monedasFile, Moneda, true)

    CSVManager.readFileCSV(
      if(iO.archivo_input == nil, do: @transaccionesFile, else: iO.archivo_input),
      Transaccion,
      true
    )
    |> Enum.filter(fn transaccion ->
      transaccion.cuenta_origen == cuenta or transaccion.cuenta_destino == cuenta
    end)
    |> Balance.porMoneda(cuenta, listMonedas, moneda)
    |> finishOperation(iO.archivo_output, Bal, false)
  end


  @doc false
  # Filtra y procesa transacciones según flags
  defp transacciones(iO, filters) do
    CSVManager.readFileCSV(
      if(iO.archivo_input == nil, do: @transaccionesFile, else: iO.archivo_input),
      Transaccion,
      true
    )
    |> filter(filters)
    |> finishOperation(iO.archivo_output, Transaccion, true)
  end


  @doc false
  # Aplica filtros recursivos sobre una lista de structs
  defp filter(list, flags) when flags != %{} do
    firstKey = hd(Map.keys(flags))

    cond do
      flags[firstKey] == nil ->
        # Ignorar filtros sin valor
        filter(list, Map.reject(flags, fn {key, _} -> firstKey == key end))
      true ->
        list
        |> Enum.filter(fn objeto ->
          map = Map.from_struct(objeto)

          cond do
            firstKey == :moneda ->
              map[:moneda_origen] == flags[firstKey] or map[:moneda_destino] == flags[firstKey]
            true ->
              map[firstKey] == flags[firstKey]
          end
        end)
        |> filter(Map.reject(flags, fn {key, _} -> firstKey == key end))
    end
  end

  # Caso base: sin filtros, retorna la lista tal cual
  defp filter(list, _) do
    list
  end


  @doc false
  # Imprime o escribe los resultados de la operación
  defp finishOperation(list, name, typeData, puntoComa) do
    cond do
      name == nil ->
        IO.inspect(list)
      true ->
        CSVManager.writeFileCSV(name, list, typeData, puntoComa)
    end
  end
end
