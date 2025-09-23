
# Ledger

Ledger es un sistema para la gestión y consulta de registros financieros, permitiendo filtrar transacciones y calcular balances por cuenta y moneda a partir de archivos CSV. El proyecto está desarrollado en Elixir y pensado para ser ejecutado desde línea de comandos o como librería.

## Estructura del Proyecto

- `lib/ledger.ex`: Módulo principal, orquesta las operaciones de balance y transacciones.
- `lib/argumentos.ex`: Validación y procesamiento de argumentos de línea de comandos.
- `lib/balance.ex`: Lógica de cálculo de balances por cuenta y moneda.
- `lib/csvmanager.ex`: Lectura y escritura de archivos CSV a structs.
- `lib/estructuras/`: Definición de structs para argumentos, balances, monedas y transacciones.
- `lib/mi_app/cli.ex`: Punto de entrada CLI.
- `data/`: Archivos CSV de entrada (`transacciones.csv`, `monedas.csv`).
- `responsesFIles/`: Archivos de salida generados.

## Uso

El sistema se ejecuta desde la línea de comandos, recibiendo como primer argumento el tipo de operación (`balance` o `transacciones`) y luego los flags correspondientes:

```bash
./ledger <operacion> [flags]
```

### Flags disponibles
- `-c1` : cuenta origen (obligatorio para balance)
- `-c2` : cuenta destino (solo para transacciones)
- `-t`  : archivo de input alternativo
- `-m`  : moneda (para convertir balances)
- `-o`  : archivo de output

## Documentación de módulos principales

### Argumentos
Valida los argumentos recibidos, verifica duplicados, flags sin valor, y llama a `Ledger.initOperation/2` si todo es correcto. Devuelve errores claros si hay problemas de sintaxis o semántica en los argumentos.

### Ledger
Orquesta la ejecución de operaciones:
- `transacciones`: filtra y devuelve/escribe transacciones según los filtros.
- `balance`: calcula balances por cuenta y moneda, usando los datos de transacciones y monedas.

### Balance
Calcula balances por cuenta, detecta valores negativos, permite conversión entre monedas usando precios en USD, y reporta errores si hay inconsistencias en los datos.

### CSVManager
Lee archivos CSV y convierte cada fila en structs, validando la cantidad de columnas y reportando errores de formato. Permite escribir resultados en archivos CSV.

### Estructuras
Define los structs para argumentos, balances, monedas y transacciones, junto con los headers esperados para la conversión desde/hacia CSV.

### MiApp.CLI
Punto de entrada para la ejecución desde línea de comandos.

## Manejo de Errores

El sistema implementa un manejo robusto de errores en todas las etapas:

- **Validación de argumentos:**
  - Se detectan flags inválidos, duplicados o sin valor, y se informa el error específico.
  - Si el tipo de operación no es reconocido, se sugiere la operación más cercana.
  - Se valida la obligatoriedad de ciertos flags según la operación.

- **Lectura de CSV:**
  - Se valida que cada fila tenga la cantidad correcta de columnas.
  - Si hay errores de formato, se reporta la línea problemática y se detiene el procesamiento.

- **Cálculo de balances:**
  - Se detectan y reportan balances negativos, retornando un error con el detalle de la cuenta.
  - Si el tipo de transacción no es reconocido, se informa la línea con el error.

- **Operaciones:**
  - Si ocurre cualquier error en la cadena de procesamiento, se retorna una tupla `{:error, mensaje}` o se imprime el error en consola.


## Ejemplo de ejecución

```bash
./ledger transacciones -c1=Cuenta1 -m=USD -o=output.csv
./ledger balance -c1=Cuenta1 -m=USD
```

## Pruebas

El proyecto incluye pruebas unitarias en la carpeta `test/` para validar la lógica de argumentos, balance y manejo de archivos.