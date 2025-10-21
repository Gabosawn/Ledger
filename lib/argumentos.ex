defmodule Argumentos do
  @moduledoc """
  Módulo para validar y procesar argumentos de línea de comandos del sistema Ledger.

  Este módulo actúa como capa de validación entre la CLI y la lógica de negocio,
  asegurando que los argumentos proporcionados sean correctos antes de ejecutar
  cualquier operación.

  ## Responsabilidades

  - Validar que la operación solicitada sea válida
  - Verificar que los flags proporcionados sean correctos para la operación
  - Detectar flags duplicados o sin valor
  - Validar que estén presentes todos los flags obligatorios
  - Sugerir correcciones usando similitud de Jaro-Winkler
  - Delegar la ejecución a `Ledger.initOperation/4`

  ## Operaciones soportadas

  ### Consultas (Estructuras.Argumentos)
  - `balance` - Consultar balance de cuenta
  - `transacciones` - Listar transacciones

  ### Gestión de Monedas (Ledger.Moneda)
  - `crear_moneda` - Crear nueva moneda
  - `editar_moneda` - Editar precio de moneda
  - `borrar_moneda` - Eliminar moneda
  - `ver_moneda` - Ver detalles de moneda

  ### Gestión de Transacciones (Ledger.Transaccion)
  - `alta_cuenta` - Dar de alta una moneda en una cuenta
  - `realizar_swap` - Intercambiar monedas
  - `realizar_transferencia` - Transferir fondos
  - `deshacer_transaccion` - Revertir última transacción
  - `ver_transaccion` - Ver detalles de transacción

  ### Gestión de Usuarios (Ledger.Usuario)
  - `crear_usuario` - Crear nueva cuenta de usuario
  - `editar_usuario` - Editar nombre de usuario
  - `borrar_usuario` - Eliminar usuario
  - `ver_usuario` - Ver detalles de usuario

  ## Flags disponibles

  - `-c1` : Cuenta origen
  - `-c2` : Cuenta destino
  - `-t`  : Archivo de entrada
  - `-m`  : Moneda
  - `-o`  : Archivo de salida
  - `-id` : ID de registro
  - `-n`  : Nombre (usuario/moneda)
  - `-p`  : Precio (moneda)
  - `-b`  : Fecha de nacimiento (usuario)
  - `-mo` : Moneda origen (transacción)
  - `-md` : Moneda destino (transacción)
  - `-u`  : Usuario (transacción)
  - `-d`  : Cuenta destino (transacción)
  - `-a`  : Monto (transacción)

  ## Formato de entrada

  Los argumentos deben seguir el formato:
  ```
  [operacion, flag1=valor1, flag2=valor2, ...]
  ```

  ## Ejemplos

      # Balance de una cuenta
      iex> Argumentos.validationArgs(["balance", "-c1=cuenta_123", "-m=USD"])
      {:ok, "Operación realizada con exito"}

      # Crear usuario
      iex> Argumentos.validationArgs(["crear_usuario", "-n=alice", "-b=1995-06-15"])
      {:ok, "Operación realizada con exito"}

      # Error: operación inválida
      iex> Argumentos.validationArgs(["balanc"])
      {:error, "Quisiste decir balance"}

      # Error: flags duplicados
      iex> Argumentos.validationArgs(["balance", "-c1=user1", "-c1=user2"])
      {:error, "Algún flag se encuentra duplicado"}
  """

  alias Ledger
  alias Estructuras.Argumentos, as: Args
  alias Ledger.Moneda, as: Moneda
  alias Ledger.Transaccion, as: Transaccion
  alias Ledger.Usuario, as: Usuario

  @argumento Args.getHeaders
  @moneda Moneda.getHeaders
  @transaccion Transaccion.getHeaders
  @usuario Usuario.getHeaders

  @doc """
  Valida los argumentos recibidos desde la línea de comandos.

  Esta es la función principal de validación que determina el tipo de operación
  y delega a las funciones de validación específicas.

  ## Proceso de validación

  1. Verifica que se hayan proporcionado argumentos
  2. Identifica el tipo de operación (primer argumento)
  3. Valida que la operación exista
  4. Si la operación no existe, sugiere alternativas usando similitud de Jaro
  5. Delega a `verifyFlags/4` para validación detallada

  ## Parámetros

  - `args` - Lista de strings con los argumentos de línea de comandos.
    Formato: `[operacion, flag1=valor1, flag2=valor2, ...]`

  ## Retorna

  - `{:ok, mensaje}` - Si la operación se ejecutó exitosamente
  - `{:error, mensaje}` - Si hubo errores de validación

  ## Sugerencias inteligentes

  Utiliza el algoritmo de distancia de Jaro-Winkler para sugerir operaciones
  similares cuando se detecta un error tipográfico (umbral de similitud: 0.84).

  ## Ejemplos

      # Sin argumentos
      iex> Argumentos.validationArgs([])
      {:error, "No se ha proporcionado ningun parámetro"}

      # Operación válida
      iex> Argumentos.validationArgs(["balance", "-c1=cuenta_123"])
      {:ok, "Operación realizada con exito"}

      # Operación inválida con sugerencia
      iex> Argumentos.validationArgs(["balanc"])
      {:error, "Quisiste decir balance"}

      # Operación muy diferente
      iex> Argumentos.validationArgs(["xyz"])
      {:error, "Escribir primero el tipo de operacion"}

      # Consulta de transacciones (flags opcionales)
      iex> Argumentos.validationArgs(["transacciones"])
      {:ok, "Operación realizada con exito"}
  """
  def validationArgs(args) do
    cond do
      Enum.empty?(args) -> {:error, "No se ha proporcionado ningun parámetro"}

      hd(args) in @argumento.operaciones -> verifyFlags(tl(args), @argumento.flags, hd(args), %Args{})

      hd(args) in @moneda.operaciones -> verifyFlags(tl(args), @moneda.flags, hd(args), %Moneda{})

      hd(args) in @transaccion.operaciones -> verifyFlags(tl(args), @transaccion.flags, hd(args), %Transaccion{})

      hd(args) in @usuario.operaciones -> verifyFlags(tl(args), @usuario.flags, hd(args), %Usuario{})

      true ->
        todas_operaciones = [@argumento.operaciones, @moneda.operaciones, @transaccion.operaciones, @usuario.operaciones] |> List.flatten()
        coindicencia =
          Enum.reduce(todas_operaciones, %{num: 0.0, palabra: ""}, fn operacion, acc ->
            simil = String.jaro_distance(hd(args), operacion)
            cond do
              simil > acc.num -> %{acc | num: simil, palabra: operacion}
              true -> acc
            end
          end)

        cond do
          coindicencia.num > 0.84 -> {:error, "Quisiste decir " <> coindicencia.palabra}
          true -> {:error, "Escribir primero el tipo de operacion"}
        end
    end

  end

  # Verifica que los flags sean válidos para la operación especificada.
  #
  # Esta función privada realiza múltiples validaciones sobre los flags:
  # - Que todos los flags sean válidos para la operación
  # - Que todos los flags tengan valores asignados
  # - Que no haya flags duplicados
  # - Que estén presentes los flags obligatorios (para ciertas operaciones)
  #
  # ## Proceso
  #
  # 1. Divide cada argumento por "=" para obtener pares flag=valor
  # 2. Verifica que todos los flags sean válidos
  # 3. Valida que no haya flags sin valor
  # 4. Valida que no haya flags duplicados
  # 5. Para transacciones específicas, valida flags obligatorios
  # 6. Delega a Ledger.initOperation/4 si todo es válido
  #
  # ## Parámetros
  #
  # - `flags` - Lista de strings con formato "flag=valor"
  # - `validFlags` - Mapa con los flags válidos para la operación
  # - `typeOperation` - String con el nombre de la operación
  # - `estructura` - Módulo de estructura correspondiente
  #
  # ## Retorna
  #
  # - `{:ok, resultado}` si la validación y ejecución son exitosas
  # - `{:error, mensaje}` si hay errores de validación
  #
  # ## Validaciones especiales
  #
  # - Para "transacciones": permite flags vacíos (consulta sin filtros)
  # - Para "alta_cuenta", "realizar_swap", "realizar_transferencia":
  #   valida que estén presentes los flags específicos requeridos
  defp verifyFlags(flags, validFlags, typeOperation, estructura) do
    keysValues = Enum.map(flags, fn arg -> String.split(arg, "=") end)

    valid = Enum.filter(keysValues, fn key ->
      Enum.at(key, 0) in List.flatten(Map.values(validFlags))
    end)

    cond do
      keysValues -- valid != [] -> {:error, "Flags invalidos. Los que se pueden usar son: " <> Enum.join(List.flatten(Map.values(validFlags)), ", ")}

      keysValues == [] and typeOperation != "transacciones" -> {:error, "No se ha proporcionado ningun flag"}

      argumentoSinValor?(keysValues) ->
        err = argumentoSinValor(keysValues)
        {:error, "El flag " <> err <> " no tiene ningun valor"}

      argumentoDuplicado?(keysValues) -> {:error, "Algún flag se encuentra duplicado"}

      typeOperation in ["alta_cuenta", "realizar_swap", "realizar_transferencia"] ->
        flagsArgs = List.flatten(keysValues)
        flagsArgs = flagsArgs -- Enum.drop_every(flagsArgs, 2)

        cond do
          Enum.all?(Transaccion.flagsBy(typeOperation), fn key -> key in flagsArgs  end) -> Ledger.initOperation(keysValues, validFlags, typeOperation, estructura)
          true ->  {:error, "La operacion #{typeOperation} debe tener los flags #{Enum.join(Transaccion.flagsBy(typeOperation), ", ")}"}
        end

      true -> Ledger.initOperation(keysValues, validFlags, typeOperation, estructura)
    end
  end

  # Verifica si hay algún flag duplicado en la lista de argumentos.
  #
  # Recorre la lista de pares [flag, valor] y cuenta cuántas veces aparece
  # cada flag. Si algún flag aparece más de una vez, retorna true.
  #
  # ## Parámetros
  #
  # - `args` - Lista de listas con formato [[flag, valor], ...]
  #
  # ## Retorna
  #
  # - `true` si hay al menos un flag duplicado
  # - `false` si todos los flags son únicos
  #
  # ## Ejemplos
  #
  #     argumentoDuplicado?([["-c1", "user1"], ["-m", "USD"], ["-c1", "user2"]])
  #     #=> true
  #
  #     argumentoDuplicado?([["-c1", "user1"], ["-m", "USD"]])
  #     #=> false
  defp argumentoDuplicado?(args) do
    Enum.any?(args, fn [arg, _] ->
      Enum.count(args, fn [arg_aux, _] -> arg == arg_aux end) > 1
    end)
  end

  # Verifica si algún flag está sin valor asignado.
  #
  # Detecta dos casos problemáticos:
  # 1. Flags que no tienen el formato "flag=valor" (lista con un solo elemento)
  # 2. Flags con formato "flag=" pero sin valor después del igual
  #
  # ## Parámetros
  #
  # - `args` - Lista de listas con formato [[flag, valor], ...] o [[flag], ...]
  #
  # ## Retorna
  #
  # - `true` si hay al menos un flag sin valor
  # - `false` si todos los flags tienen valor
  #
  # ## Ejemplos
  #
  #     # Flag sin "="
  #     argumentoSinValor?([["-c1"]])
  #     #=> true
  #
  #     # Flag con "=" pero sin valor
  #     argumentoSinValor?([["-c1", ""]])
  #     #=> true
  #
  #     # Todos los flags con valor
  #     argumentoSinValor?([["-c1", "user1"], ["-m", "USD"]])
  #     #=> false
  defp argumentoSinValor?(args) do
    arg_sin_valor = Enum.reject(args, fn arg ->
      Enum.count(arg) > 1
    end)
    cond do
      arg_sin_valor != [] -> true

      true -> Enum.any?(args, fn [_, value] -> value == "" end)
    end

  end

  # Devuelve el primer flag que está sin valor.
  #
  # Busca en la lista de argumentos el primero que no tenga valor asignado
  # y retorna el nombre del flag para incluirlo en el mensaje de error.
  #
  # ## Parámetros
  #
  # - `args` - Lista de listas con formato [[flag, valor], ...] o [[flag], ...]
  #
  # ## Retorna
  #
  # String con el nombre del primer flag sin valor encontrado
  #
  # ## Ejemplos
  #
  #     argumentoSinValor([["-c1", "user"], ["-m"], ["-o", "output"]])
  #     #=> "-m"
  #
  #     argumentoSinValor([["-c1", ""], ["-m", "USD"]])
  #     #=> "-c1"
  defp argumentoSinValor(args) do
    Enum.find(args, fn arg -> tl(arg) == [] or tl(arg) == [""] end)
    |> Enum.at(0)
  end

end
