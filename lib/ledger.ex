defmodule Ledger do
  @moduledoc """
  Módulo principal del sistema Ledger para coordinar operaciones financieras.

  Este módulo actúa como orquestador central del sistema, coordinando la validación
  de argumentos, la ejecución de operaciones y la presentación de resultados.

  ## Responsabilidades

  - **Coordinación**: Conecta el módulo de validación (`Argumentos`) con los módulos de lógica de negocio
  - **Transformación de datos**: Convierte flags de línea de comandos en parámetros para structs
  - **Delegación**: Delega la ejecución a los módulos especializados (Usuario, Moneda, Transaccion, etc.)
  - **Presentación de resultados**: Maneja la salida de datos (consola o archivo CSV)

  ## Flujo de operación

  1. `Argumentos.validationArgs/1` valida los argumentos de entrada
  2. `Ledger.initOperation/4` transforma flags a mapa de parámetros
  3. Se ejecuta el changeset correspondiente del módulo especializado
  4. `Ledger.finishOperation/4` presenta los resultados (pantalla o archivo)

  ## Tipos de operaciones soportadas

  ### Consultas (Estructuras.Argumentos)
  - `balance` - Consultar balance de cuenta
  - `transacciones` - Listar transacciones

  ### Gestión de Usuarios (Ledger.Usuario)
  - `crear_usuario`, `editar_usuario`, `borrar_usuario`, `ver_usuario`

  ### Gestión de Monedas (Ledger.Moneda)
  - `crear_moneda`, `editar_moneda`, `borrar_moneda`, `ver_moneda`

  ### Gestión de Transacciones (Ledger.Transaccion)
  - `alta_cuenta`, `realizar_swap`, `realizar_transferencia`
  - `deshacer_transaccion`, `ver_transaccion`

  ## Formatos de salida

  - **Consola**: Tabla formateada con ANSI (si no se especifica `-o`)
  - **Archivo CSV**: Archivo en `responsesFiles/` (si se especifica `-o`)

  ## Ejemplo de flujo completo

      # 1. Usuario ejecuta desde CLI
      ./ledger balance -c1=cuenta_123 -m=USD -o=balance.csv

      # 2. MiApp.CLI normaliza argumentos
      ["balance", "-c1=cuenta_123", "-m=USD", "-o=balance.csv"]

      # 3. Argumentos.validationArgs valida y llama a:
      Ledger.initOperation(
        [["-c1", "cuenta_123"], ["-m", "USD"], ["-o", "balance.csv"]],
        %{cuenta_origen: "-c1", moneda: "-m", archivo_output: "-o"},
        "balance",
        Estructuras.Argumentos
      )

      # 4. Ledger transforma a:
      %{cuenta_origen: "cuenta_123", moneda: "USD", archivo_output: "balance.csv"}

      # 5. Ejecuta:
      Estructuras.Argumentos.changeset(:balance, params)

      # 6. Finalmente presenta resultados:
      Ledger.finishOperation(resultados, "balance.csv", Estructuras.Balance, false)

  ## Diseño modular

  El sistema sigue una arquitectura en capas:
  - **CLI** → `MiApp.CLI` (normalización de entrada)
  - **Validación** → `Argumentos` (validación de flags y operaciones)
  - **Coordinación** → `Ledger` (este módulo)
  - **Lógica de negocio** → `Estructuras.*`, `Ledger.Usuario`, `Ledger.Moneda`, `Ledger.Transaccion`
  - **Presentación** → `Herramientas`, `CSVManager`
  """

  alias CSVManager
  alias Balance

  @doc """
  Inicializa y ejecuta una operación del sistema Ledger.

  Esta función es el punto central de coordinación. Recibe flags validados desde
  el módulo `Argumentos` y los transforma en parámetros para ejecutar la operación
  correspondiente en el módulo especializado.

  ## Proceso

  1. Extrae las claves válidas del mapa de flags
  2. Busca el valor correspondiente a cada flag en los argumentos recibidos
  3. Construye un mapa de parámetros con formato `%{campo: valor, ...}`
  4. Convierte el tipo de operación a átomo
  5. Ejecuta el changeset del módulo especializado
  6. Retorna el resultado de la operación

  ## Parámetros

  - `keysValues` - Lista de listas con formato `[[flag, valor], ...]`. Ejemplo:
    ```elixir
    [["-c1", "cuenta_123"], ["-m", "USD"], ["-o", "output.csv"]]
    ```

  - `mapValidFlags` - Mapa que relaciona nombres de campos con sus flags. Ejemplo:
    ```elixir
    %{cuenta_origen: "-c1", moneda: "-m", archivo_output: "-o"}
    # o con alias:
    %{cuenta_origen: ["-c1", "-u"], moneda: ["-m", "-mo"]}
    ```

  - `typeOperation` - String con el nombre de la operación a ejecutar. Ejemplos:
    - `"balance"`, `"transacciones"`
    - `"crear_usuario"`, `"editar_moneda"`
    - `"alta_cuenta"`, `"realizar_swap"`

  - `estructura` - Módulo que define la estructura y operaciones. Ejemplos:
    - `Estructuras.Argumentos` (para balance/transacciones)
    - `Ledger.Usuario` (para operaciones de usuario)
    - `Ledger.Moneda` (para operaciones de moneda)
    - `Ledger.Transaccion` (para operaciones de transacción)

  ## Retorna

  El resultado del changeset ejecutado, típicamente:
  - `{:ok, "Operación realizada con exito"}` - Si fue exitosa
  - `{:error, [operacion: "mensaje de error"]}` - Si hubo errores

  ## Transformación de flags

  La función maneja dos tipos de flags:
  - **Simples**: `"-c1"` → valor único
  - **Con alias**: `["-c1", "-u"]` → acepta cualquiera de los dos

  ## Ejemplos

      # Balance de cuenta
      iex> Ledger.initOperation(
      ...>   [["-c1", "alice"], ["-m", "USD"]],
      ...>   %{cuenta_origen: "-c1", moneda: "-m", archivo_output: "-o"},
      ...>   "balance",
      ...>   Estructuras.Argumentos
      ...> )
      {:ok, "Operación realizada con exito"}
      # Transforma a: %{cuenta_origen: "alice", moneda: "USD", archivo_output: nil}
      # Ejecuta: Estructuras.Argumentos.changeset(:balance, params)

      # Crear usuario
      iex> Ledger.initOperation(
      ...>   [["-n", "bob"], ["-b", "1995-06-15"]],
      ...>   %{id: "-id", username: "-n", nacimiento: "-b"},
      ...>   "crear_usuario",
      ...>   Ledger.Usuario
      ...> )
      {:ok, "Operación realizada con exito"}
      # Transforma a: %{id: nil, username: "bob", nacimiento: "1995-06-15"}
      # Ejecuta: Ledger.Usuario.changeset(:crear_usuario, params)

      # Alta de cuenta con flags con alias
      iex> Ledger.initOperation(
      ...>   [["-u", "1"], ["-m", "1"]],
      ...>   %{cuenta_origen_id: ["-o", "-u"], moneda_origen_id: ["-mo", "-m"]},
      ...>   "alta_cuenta",
      ...>   Ledger.Transaccion
      ...> )
      {:ok, "Operación realizada con exito"}
      # El flag "-u" coincide con el alias de cuenta_origen_id
      # El flag "-m" coincide con el alias de moneda_origen_id
  """
  def initOperation(keysValues, mapValidFlags, typeOperation, estructura) do
    keys = Map.keys(mapValidFlags)

    flagsMap = Enum.reduce(keys, %{}, fn key_flag, acc ->
      existe = Enum.find(keysValues, fn [key_arg, _] -> esta?(key_arg, mapValidFlags[key_flag]) end)
      if is_nil(existe) do
        Map.put(acc, key_flag, existe)
      else
        Map.put(acc, key_flag, Enum.at(existe, 1))
      end
    end)

    lib = estructura.__struct__

    lib.changeset(String.to_atom(typeOperation), flagsMap)
  end

  # Verifica si un argumento coincide con un flag o lista de flags.
  #
  # Esta función privada maneja dos casos:
  # 1. El flag es una lista (tiene alias): verifica si arg está en la lista
  # 2. El flag es un string: verifica igualdad exacta
  #
  # ## Parámetros
  #
  # - `arg` - String con el flag del argumento (ej: "-c1", "-u")
  # - `objeto` - Flag válido, puede ser:
  #   - Lista de strings: `["-c1", "-u"]` (flag con alias)
  #   - String: `"-m"` (flag simple)
  #
  # ## Retorna
  #
  # - `true` si el argumento coincide con el flag
  # - `false` si no coincide
  #
  # ## Ejemplos
  #
  #     # Flag con alias
  #     esta?("-u", ["-c1", "-u"])
  #     #=> true
  #
  #     esta?("-c1", ["-c1", "-u"])
  #     #=> true
  #
  #     esta?("-m", ["-c1", "-u"])
  #     #=> false
  #
  #     # Flag simple
  #     esta?("-m", "-m")
  #     #=> true
  #
  #     esta?("-mo", "-m")
  #     #=> false
  defp esta?(arg, objeto) when is_list(objeto) do
    arg in objeto
  end

  defp esta?(arg, objeto) when is_bitstring(objeto) do
    arg == objeto
  end


  @doc """
  Finaliza una operación presentando los resultados en consola o archivo CSV.

  Esta función determina cómo presentar los resultados de una operación según
  si se especificó o no un archivo de salida.

  ## Parámetros

  - `list` - Lista de structs con los resultados de la operación. Ejemplos:
    - Lista de `%Estructuras.Balance{}`
    - Lista de `%Estructuras.Transaccion{}`
    - Lista de otros structs del sistema

  - `name` - Nombre del archivo de salida (string) o `nil`:
    - Si es `nil`: muestra resultados en consola con tabla formateada
    - Si es string: guarda resultados en archivo CSV

  - `typeData` - Módulo del tipo de datos para obtener encabezados. Ejemplos:
    - `Estructuras.Balance`
    - `Estructuras.Transaccion`
    - `Ledger.Usuario`

  - `puntoComa` - Booleano que indica el separador CSV:
    - `true`: usa punto y coma (`;`)
    - `false`: usa igual (`=`)

  ## Retorna

  - Si `name` es `nil`: tupla `{tabla_formateada, "Operación realizada con exito"}`
  - Si `name` es string: `{:ok, "Operación realizada con exito"}`

  ## Presentación en consola

  Utiliza `Herramientas.mostrar_por_pantalla/2` para formatear los datos en una
  tabla ANSI visualmente agradable.

  ## Escritura en archivo

  Utiliza `CSVManager.writeFileCSV/4` para guardar los datos en formato CSV
  en el directorio `responsesFiles/`.

  ## Ejemplos

      # Mostrar balances en consola
      iex> balances = [
      ...>   %Estructuras.Balance{MONEDA: "USD", BALANCE: Decimal.new(1500)},
      ...>   %Estructuras.Balance{MONEDA: "EUR", BALANCE: Decimal.new(750)}
      ...> ]
      iex> Ledger.finishOperation(balances, nil, Estructuras.Balance, false)
      {tabla_formateada, "Operación realizada con exito"}
      # Muestra:
      # ┌────────┬─────────┐
      # │ MONEDA │ BALANCE │
      # ├────────┼─────────┤
      # │ USD    │ 1500    │
      # │ EUR    │ 750     │
      # └────────┴─────────┘

      # Guardar transacciones en CSV
      iex> transacciones = [%Estructuras.Transaccion{...}]
      iex> Ledger.finishOperation(transacciones, "salida.csv", Estructuras.Transaccion, true)
      {:ok, "Operación realizada con exito"}
      # Crea: responsesFiles/salida.csv

      # Guardar balance en CSV con separador ;
      iex> Ledger.finishOperation(balances, "balance_output.csv", Estructuras.Balance, true)
      {:ok, "Operación realizada con exito"}
      # Crea: responsesFiles/balance_output.csv
      # Contenido:
      # MONEDA;BALANCE
      # USD;1500.000000
      # EUR;750.000000

      # Mostrar usuarios en consola
      iex> usuarios = [%{id: 1, username: "alice", nacimiento: ~D[1995-06-15]}]
      iex> Ledger.finishOperation(usuarios, nil, Ledger.Usuario, false)
      {tabla_formateada, "Operación realizada con exito"}
  """
  def finishOperation(list, name, typeData, puntoComa) do
    cond do
      name == nil -> Herramientas.mostrar_por_pantalla(typeData.getHeaders(), Enum.map(list, fn map -> Map.from_struct(map) end))
      true -> CSVManager.writeFileCSV(name, list, typeData, puntoComa)
    end
  end
end
