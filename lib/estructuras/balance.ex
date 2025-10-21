defmodule Estructuras.Balance do
  @moduledoc """
  Módulo para gestionar y calcular balances de cuentas en el sistema Ledger.

  Este módulo proporciona funcionalidades para:
  - Calcular el balance de una cuenta específica
  - Realizar conversiones entre diferentes monedas
  - Procesar transacciones de tipo alta, transferencia y swap
  - Generar reportes de balance en una o múltiples monedas

  ## Estructura de datos

  Cada balance contiene:
  - `MONEDA` - Código de la moneda (ej: USD, EUR, BTC)
  - `BALANCE` - Monto en formato Decimal

  ## Tipos de transacciones soportadas

  - **alta_cuenta**: Depósito inicial en una cuenta
  - **transferencia**: Transferencia de fondos entre cuentas
  - **swap**: Intercambio de una moneda por otra

  ## Ejemplos

      # Obtener balance de una cuenta en todas las monedas
      balance_cuenta(transacciones, monedas, "cuenta_123", nil)

      # Obtener balance de una cuenta en USD específicamente
      balance_cuenta(transacciones, monedas, "cuenta_123", "USD")
  """

  import Ecto.Changeset

  @headers [:MONEDA, :BALANCE]

  defstruct @headers

  @doc """
  Retorna los headers (campos) disponibles para la estructura de balance.

  ## Retorna

  Una lista con los átomos que representan los campos de la estructura:
  - `:MONEDA` - Código de la moneda
  - `:BALANCE` - Monto del balance

  ## Ejemplos

      iex> Estructuras.Balance.getHeaders()
      [:MONEDA, :BALANCE]
  """
  def getHeaders() do
    @headers
  end

  # Convierte un monto de una moneda a otra utilizando USD como moneda intermedia.
  #
  # Esta función realiza la conversión mediante el método del tipo de cambio triangular:
  # 1. Convierte el monto de la moneda origen a USD
  # 2. Convierte el resultado de USD a la moneda destino
  #
  # ## Parámetros
  #
  # - `moneda_origen` - Código de la moneda de origen (ej: "EUR")
  # - `moneda_destino` - Código de la moneda de destino (ej: "USD")
  # - `monto` - Cantidad a convertir (puede ser número o Decimal)
  # - `listaDivisas` - Lista de estructuras de moneda con precios en USD
  #
  # ## Retorna
  #
  # Un mapa con:
  # - `:MONEDA` - La moneda destino
  # - `:BALANCE` - El monto convertido en formato Decimal
  #
  # ## Ejemplos
  #
  #     # Convertir 100 EUR a USD
  #     cambioDe("EUR", "USD", 100, lista_monedas)
  #     #=> %{MONEDA: "USD", BALANCE: #Decimal<110.5>}
  defp cambioDe(moneda_origen, moneda_destino, monto, listaDivisas) do
    origenDolar =
      Enum.find(listaDivisas, fn divisa ->
        divisa.nombre_moneda == moneda_origen
      end)
      |> Map.get(:precio_usd)
      |> Decimal.new()

    destinoDolar =
      Enum.find(listaDivisas, fn divisa ->
        divisa.nombre_moneda == moneda_destino
      end)
      |> Map.get(:precio_usd)
      |> Decimal.new()

    %{MONEDA: moneda_destino, BALANCE: (Decimal.mult(origenDolar, Decimal.div(monto, destinoDolar)))}
  end

  # Convierte todos los balances a una sola moneda y los suma.
  #
  # Esta función toma una lista de balances en diferentes monedas y los convierte
  # todos a la moneda especificada, sumando los montos resultantes para obtener
  # un balance total en esa moneda única.
  #
  # ## Parámetros
  #
  # - `balance` - Lista de mapas con `:MONEDA` y `:BALANCE`
  # - `moneda` - Código de la moneda destino para la conversión
  # - `listaDivisas` - Lista de estructuras de moneda con precios en USD
  #
  # ## Retorna
  #
  # Un mapa con:
  # - `:MONEDA` - La moneda especificada
  # - `:BALANCE` - La suma total de todos los balances convertidos
  #
  # ## Ejemplos
  #
  #     balances = [
  #       %{MONEDA: "USD", BALANCE: Decimal.new(100)},
  #       %{MONEDA: "EUR", BALANCE: Decimal.new(50)}
  #     ]
  #     balanceUnaSolaMoneda(balances, "USD", lista_monedas)
  #     #=> %{MONEDA: "USD", BALANCE: #Decimal<155.5>}
  defp balanceUnaSolaMoneda(balance, moneda, listaDivisas) do
    Enum.map(balance, fn bal ->
      cambioDe(bal[:MONEDA], moneda, bal[:BALANCE], listaDivisas)
    end) |> Enum.reduce(%{MONEDA: moneda, BALANCE: Decimal.new(0)}, fn bal, acc ->
      %{acc | BALANCE: Decimal.add(bal[:BALANCE], acc[:BALANCE])}
    end)
  end

  # Agrupa y suma los balances por moneda única.
  #
  # Esta función toma una lista de balances que pueden tener monedas duplicadas
  # y las consolida sumando los balances de la misma moneda. El resultado es
  # una lista donde cada moneda aparece solo una vez con su balance total.
  #
  # ## Parámetros
  #
  # - `balance` - Lista de mapas con `:MONEDA` y `:BALANCE`, puede contener duplicados
  #
  # ## Retorna
  #
  # Lista de mapas con `:MONEDA` y `:BALANCE` únicos, con balances sumados
  #
  # ## Ejemplos
  #
  #     balances = [
  #       %{MONEDA: "USD", BALANCE: Decimal.new(100)},
  #       %{MONEDA: "USD", BALANCE: Decimal.new(50)},
  #       %{MONEDA: "EUR", BALANCE: Decimal.new(75)}
  #     ]
  #     uniqDeCadaMoneda(balances)
  #     #=> [
  #       %{MONEDA: "USD", BALANCE: #Decimal<150>},
  #       %{MONEDA: "EUR", BALANCE: #Decimal<75>}
  #     ]
  defp uniqDeCadaMoneda(balance) do
    Enum.reduce(balance, [], fn bal, acc ->
      cond do
        Enum.any?(acc, fn acumulador -> acumulador[:MONEDA] == bal[:MONEDA] end) ->
          Enum.map(acc, fn acumulador ->
            if acumulador[:MONEDA] == bal[:MONEDA] do
              %{acumulador | BALANCE: Decimal.add(bal[:BALANCE], acumulador[:BALANCE])}
            else
              acumulador
            end
          end)

        true ->
          acc ++ [bal]
      end
    end)
  end

  # Extrae el monto de una transacción de tipo alta de cuenta.
  #
  # Procesa una transacción de alta de cuenta y devuelve el balance inicial
  # depositado en la cuenta.
  #
  # ## Parámetros
  #
  # - `transaccion` - Estructura de transacción con tipo "alta_cuenta"
  #
  # ## Retorna
  #
  # Un mapa con:
  # - `:MONEDA` - La moneda de origen de la transacción
  # - `:BALANCE` - El monto depositado en formato Decimal
  #
  # ## Ejemplos
  #
  #     transaccion = %{tipo: "alta_cuenta", moneda_origen: "USD", monto: 1000}
  #     montos_por_alta(transaccion)
  #     #=> %{MONEDA: "USD", BALANCE: #Decimal<1000>}
  defp montos_por_alta(transaccion) do
    %{MONEDA: transaccion.moneda_origen,
      BALANCE: Decimal.new(transaccion.monto)}
  end

  # Extrae el monto de una transacción de tipo transferencia para una cuenta específica.
  #
  # Procesa una transacción de transferencia y determina si la cuenta especificada
  # es origen (se resta el monto) o destino (se suma el monto).
  #
  # ## Parámetros
  #
  # - `transaccion` - Estructura de transacción con tipo "transferencia"
  # - `cuenta` - Identificador de la cuenta para calcular su balance
  #
  # ## Retorna
  #
  # Un mapa con:
  # - `:MONEDA` - La moneda de la transacción
  # - `:BALANCE` - El monto negativo si es cuenta origen, positivo si es destino
  #
  # ## Ejemplos
  #
  #     # Cuenta como origen (se debita)
  #     transaccion = %{tipo: "transferencia", cuenta_origen: "A", cuenta_destino: "B",
  #                     moneda_origen: "USD", monto: 100}
  #     montos_por_transferencia(transaccion, "A")
  #     #=> %{MONEDA: "USD", BALANCE: #Decimal<-100>}
  #
  #     # Cuenta como destino (se acredita)
  #     montos_por_transferencia(transaccion, "B")
  #     #=> %{MONEDA: "USD", BALANCE: #Decimal<100>}
  defp montos_por_transferencia(transaccion, cuenta) do
    cond do
      cuenta == transaccion.cuenta_origen ->
        %{MONEDA: transaccion.moneda_origen,
          BALANCE: Decimal.new(transaccion.monto) |> Decimal.negate()}

      cuenta == transaccion.cuenta_destino ->
        %{MONEDA: transaccion.moneda_origen,
          BALANCE: Decimal.new(transaccion.monto)}
    end
  end

  # Procesa una transacción de tipo swap (intercambio de monedas).
  #
  # Para una operación swap, se genera un débito en la moneda origen y un crédito
  # en la moneda destino. El crédito se calcula usando la tasa de cambio actual.
  #
  # ## Parámetros
  #
  # - `transaccion` - Estructura de transacción con tipo "swap"
  # - `lista_monedas` - Lista de estructuras de moneda con precios en USD
  #
  # ## Retorna
  #
  # Una lista con dos mapas:
  # 1. Balance negativo en la moneda origen (lo que se entrega)
  # 2. Balance positivo en la moneda destino (lo que se recibe)
  #
  # ## Ejemplos
  #
  #     transaccion = %{tipo: "swap", moneda_origen: "USD", moneda_destino: "EUR", monto: 100}
  #     montos_por_swap(transaccion, lista_monedas)
  #     #=> [
  #       %{MONEDA: "USD", BALANCE: #Decimal<-100>},
  #       %{MONEDA: "EUR", BALANCE: #Decimal<92.5>}
  #     ]
  defp montos_por_swap(transaccion, lista_monedas) do
    desde = %{MONEDA: transaccion.moneda_origen,
              BALANCE: Decimal.new(transaccion.monto) |> Decimal.negate()}
    hacia = cambioDe(transaccion.moneda_origen, transaccion.moneda_destino, transaccion.monto, lista_monedas)

    [desde, hacia]
  end

  # Procesa todas las transacciones de una cuenta y extrae los montos por moneda.
  #
  # Esta función analiza cada transacción y determina cómo afecta el balance de
  # la cuenta según el tipo de transacción (alta, transferencia o swap).
  #
  # ## Parámetros
  #
  # - `transacciones_cuenta` - Lista de transacciones asociadas a la cuenta
  # - `estructura_monedas` - Lista de estructuras de moneda con precios en USD
  # - `cuenta` - Identificador de la cuenta para calcular su balance
  #
  # ## Retorna
  #
  # Lista aplanada de mapas con `:MONEDA` y `:BALANCE` para cada operación
  #
  # ## Ejemplos
  #
  #     transacciones = [
  #       %{tipo: "alta_cuenta", moneda_origen: "USD", monto: 1000},
  #       %{tipo: "transferencia", cuenta_origen: "A", cuenta_destino: "B",
  #         moneda_origen: "USD", monto: 100}
  #     ]
  #     montos_por_moneda(transacciones, lista_monedas, "A")
  #     #=> [
  #       %{MONEDA: "USD", BALANCE: #Decimal<1000>},
  #       %{MONEDA: "USD", BALANCE: #Decimal<-100>}
  #     ]
  defp montos_por_moneda(transacciones_cuenta, estructura_monedas, cuenta) do
    Enum.map(transacciones_cuenta, fn transaccion ->
      cond do
        transaccion.tipo == "alta_cuenta" -> montos_por_alta(transaccion)
        transaccion.tipo == "transferencia" ->  montos_por_transferencia(transaccion, cuenta)
        transaccion.tipo == "swap" -> montos_por_swap(transaccion, estructura_monedas)
      end
    end)
    |> List.flatten()
  end

  @doc """
  Calcula el balance de una cuenta basado en sus transacciones.

  Esta función es el punto principal para calcular balances. Procesa todas las
  transacciones de una cuenta y genera un reporte del balance, que puede ser
  en una moneda específica o en todas las monedas con movimientos.

  ## Validaciones

  - Verifica que ningún balance sea negativo (saldo insuficiente)
  - Agrupa y suma balances por moneda
  - Puede convertir todos los balances a una sola moneda si se especifica

  ## Parámetros

  - `transacciones_cuenta` - Lista de transacciones asociadas a la cuenta
  - `estructura_monedas` - Lista de estructuras de moneda con precios en USD
  - `cuenta` - Identificador de la cuenta
  - `nombre_moneda` - (opcional) Código de moneda para convertir todo el balance.
    Si es `nil`, retorna balances en todas las monedas

  ## Retorna

  - `{:ok, [%Estructuras.Balance{}]}` - Lista de estructuras de balance si es exitoso
  - `{:error, String.t()}` - Mensaje de error si hay balances negativos

  ## Ejemplos

      # Balance en todas las monedas
      iex> balance_cuenta(transacciones, monedas, "cuenta_123", nil)
      {:ok, [
        %Estructuras.Balance{MONEDA: "USD", BALANCE: #Decimal<1500>},
        %Estructuras.Balance{MONEDA: "EUR", BALANCE: #Decimal<750>}
      ]}

      # Balance convertido a USD
      iex> balance_cuenta(transacciones, monedas, "cuenta_123", "USD")
      {:ok, [%Estructuras.Balance{MONEDA: "USD", BALANCE: #Decimal<2325.50>}]}

      # Error por balance negativo
      iex> balance_cuenta(transacciones_invalidas, monedas, "cuenta_456", nil)
      {:error, "Las transacciones de la cuenta cuenta_456 tienen balances negativos"}
  """
  def balance_cuenta(transacciones_cuenta, estructura_monedas, cuenta, nombre_moneda) do
    montos = montos_por_moneda(transacciones_cuenta, estructura_monedas, cuenta)
    |> uniqDeCadaMoneda()
    cond do
      Enum.any?(montos, fn bal -> Decimal.compare(bal[:BALANCE], 0) == :lt end) -> {:error, "Las transacciones de la cuenta " <> cuenta <> " tienen balances negativos"}
      nombre_moneda == nil -> {:ok, Enum.map(montos, fn bal -> struct!(Estructuras.Balance, bal) end)}
      true -> {:ok, [struct!(Estructuras.Balance, balanceUnaSolaMoneda(montos, nombre_moneda, estructura_monedas))]}
    end
  end

  @doc """
  Inicializa y ejecuta una operación de consulta de balance.

  Esta función es el punto de entrada principal para las operaciones de balance.
  Obtiene los parámetros del changeset, carga las transacciones y monedas necesarias,
  calcula el balance y genera el archivo de salida.

  ## Proceso

  1. Extrae parámetros del changeset (archivo entrada, cuenta, salida, moneda)
  2. Obtiene las transacciones relacionadas con la cuenta
  3. Carga la información de las monedas disponibles
  4. Calcula el balance de la cuenta
  5. Genera el archivo de salida con los resultados

  ## Parámetros

  - `changeset` - Changeset de Ecto con los campos:
    - `:archivo_input` - Ruta del archivo de transacciones (opcional)
    - `:cuenta_origen` - Identificador de la cuenta a consultar
    - `:archivo_output` - Ruta del archivo de salida (opcional)
    - `:moneda` - Código de moneda para el reporte (opcional)

  ## Retorna

  - `{:ok, resultado}` - Si la operación fue exitosa y se generó el archivo
  - `{:error, Ecto.Changeset.t()}` - Si hubo errores, con el changeset actualizado

  ## Errores posibles

  - Sin transacciones: Si no existen transacciones para la cuenta
  - Balance negativo: Si alguna transacción deja balance negativo

  ## Ejemplos

      # Consulta exitosa
      iex> changeset = cast(%Estructuras.Argumentos{},
      ...>   %{cuenta_origen: "123", moneda: "USD"},
      ...>   [:cuenta_origen, :moneda])
      iex> initOperation(changeset)
      {:ok, resultado}

      # Sin transacciones
      iex> changeset = cast(%Estructuras.Argumentos{},
      ...>   %{cuenta_origen: "cuenta_sin_movimientos"},
      ...>   [:cuenta_origen])
      iex> initOperation(changeset)
      {:error, %Ecto.Changeset{errors: [transacciones: {"No existen transacciones", _}]}}
  """
  def initOperation(changeset) do
    input = get_field(changeset, :archivo_input)
    origen = get_field(changeset, :cuenta_origen)
    output = get_field(changeset, :archivo_output)
    moneda = get_field(changeset, :moneda)

    data = Estructuras.Transaccion.obtenerTransacciones(origen, origen, nil, input)

    case data do
      [] -> {:error, add_error(changeset, :transacciones, "No existen transacciones")}
      _ ->
        monedas = Estructuras.Moneda.obtenerMonedas()
        {status, res} = balance_cuenta(data, monedas, origen, moneda)
        case status do
          :error -> {:error, add_error(changeset, :balance, res)}
          :ok -> Ledger.finishOperation(res, output, Estructuras.Balance, false)
        end
    end
  end
end
