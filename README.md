
# Ledger 💰

Sistema completo de gestión financiera desarrollado en Elixir para el manejo de cuentas, monedas y transacciones. Ledger permite realizar operaciones CRUD sobre usuarios, monedas y transacciones, además de consultar balances y generar reportes.

Para iniciar el sistema en su carpeta personal usar:
```bash
make init
```

[![Elixir](https://img.shields.io/badge/Elixir-1.14+-purple.svg)](https://elixir-lang.org)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-14+-blue.svg)](https://www.postgresql.org)

## 📋 Tabla de Contenidos

- [Características](#-características)
- [Requisitos](#-requisitos)
- [Configuración](#-configuración)
- [Uso](#-uso)
- [Operaciones Disponibles](#-operaciones-disponibles)
- [Ejemplos de Uso](#-ejemplos-de-uso)
- [Comandos útiles (Makefile)](#️-comandos-útiles-makefile)
- [Manejo de Errores](#️-manejo-de-errores)
- [Características de Seguridad](#-características-de-seguridad)

## ✨ Características

### Gestión de Usuarios
- ✅ Crear usuarios con validación de edad (mayores de 18 años)
- ✅ Editar nombres de usuario
- ✅ Consultar información de usuarios
- ✅ Eliminar usuarios (solo si no tienen transacciones)

### Gestión de Monedas
- ✅ Crear monedas con precio en USD
- ✅ Actualizar precios de monedas
- ✅ Consultar información de monedas
- ✅ Eliminar monedas (solo si no han sido utilizadas)

### Gestión de Transacciones
- ✅ **Alta de cuenta**: Registrar una moneda en la cuenta de un usuario
- ✅ **Transferencias**: Transferir fondos entre cuentas
- ✅ **Swaps**: Intercambiar una moneda por otra
- ✅ **Deshacer transacciones**: Revertir la última transacción
- ✅ Consultar detalles de transacciones

### Reportes y Consultas
- ✅ Calcular balances por cuenta y moneda
- ✅ Conversión automática entre monedas
- ✅ Listar transacciones con filtros avanzados
- ✅ Exportar resultados a CSV o mostrar en consola

### Características Técnicas
- 🔒 Validación exhaustiva de datos con Ecto
- 💾 Persistencia en PostgreSQL
- 📊 Manejo de decimales precisos para cálculos financieros
- 🎨 Salida formateada en tablas ANSI para consola
- 📁 Importación/exportación de datos en CSV
- 🔄 Altas automáticas de monedas cuando es necesario
- ⚠️ Validación de fondos suficientes antes de transacciones
- 🔙 Sistema de deshacer transacciones con validación de orden

## 🔧 Requisitos

- **Elixir**: 1.14 o superior
- **Erlang/OTP**: 24 o superior
- **PostgreSQL**: 14 o superior
- **Docker** (opcional): Para ejecutar PostgreSQL en contenedor

## ⚙️ Configuración

### Variables de entorno

El proyecto usa diferentes archivos de configuración según el entorno:

- **Desarrollo**: `config/dev.exs`
- **Testing**: `config/test.exs`
- **Producción**: `config/runtime.exs`

### Configuración de base de datos

Edita `config/dev.exs` para ajustar la conexión a PostgreSQL:

```elixir
config :ledger, Ledger.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "ledger_dev",
  port: 5432
```

## 🚀 Uso

### Formato general de comandos

```bash
./ledger <operación> [flags]
```

## 📚 Operaciones Disponibles

### 👤 Gestión de Usuarios

| Flag  | Descripción                      |
|-------|----------------------------------|
| `-id` | ID de registro                   |
| `-n`  | Nombre                           |
| `-b`  | Fecha de nacimiento (YYYY-MM-DD) |

#### Crear usuario
```bash
./ledger crear_usuario -n=alice -b=1995-06-15
```

#### Editar usuario
```bash
./ledger editar_usuario -id=1 -n=alice_updated
```

#### Ver usuario
```bash
./ledger ver_usuario -id=1
```

#### Borrar usuario
```bash
./ledger borrar_usuario -id=5
```

### 💱 Gestión de Monedas

| Flag  | Descripción                      |
|-------|----------------------------------|
| `-id` | ID de registro                   |
| `-n`  | Nombre                           |
| `-p`  | Precio en USD                    |

#### Crear moneda
```bash
./ledger crear_moneda -n=USD -p=1.0000
./ledger crear_moneda -n=EUR -p=1.08
./ledger crear_moneda -n=BTC -p=45000.00
```

#### Editar moneda
```bash
./ledger editar_moneda -id=1 -p=1.05
```

#### Ver moneda
```bash
./ledger ver_moneda -id=1
```

#### Borrar moneda
```bash
./ledger borrar_moneda -id=5
```

### 💸 Gestión de Transacciones

| Flag  | Descripción                      |
|-------|----------------------------------|
| `-id` | ID de registro                   |
| `-u`  | Usuario                          |
| `-o`  | Cuenta origen                    |
| `-d`  | Cuenta destino                   |
| `-m`  | Moneda                           |
| `-mo` | Moneda origen                    |
| `-md` | Moneda destino                   |
| `-a`  | Monto                            |

#### Alta de cuenta (registrar moneda en cuenta)
```bash
./ledger alta_cuenta -u=1 -m=1 -a=1000
# Usuario 1 da de alta la moneda 1 con 1000 unidades
```

#### Realizar transferencia
```bash
./ledger realizar_transferencia -o=1 -d=2 -m=1 -a=100
# Transferir 100 unidades de moneda 1 del usuario 1 al usuario 2
```

#### Realizar swap (intercambio de monedas)
```bash
./ledger realizar_swap -u=1 -mo=1 -md=2 -a=50
# Usuario 1 intercambia 50 unidades de moneda 1 por moneda 2
```

#### Ver transacción
```bash
./ledger ver_transaccion -id=10
```

#### Deshacer transacción
```bash
./ledger deshacer_transaccion -id=15
```

### 📊 Consultas y Reportes

| Flag  | Descripción                      |
|-------|----------------------------------|
| `-m`  | Moneda                           |
| `-c1` | Cuenta origen                    |
| `-c2` | Cuenta destino                   |
| `-t`  | Archivo de entrada CSV           |
| `-o`  | Archivo de salida CSV            |

#### Consultar balance de una cuenta

```bash
# Balance en todas las monedas
./ledger balance -c1=alice

# Balance en USD específicamente
./ledger balance -c1=alice -m=USD

# Guardar balance en archivo CSV
./ledger balance -c1=alice -o=balance_alice.csv
```

#### Listar transacciones

```bash
# Todas las transacciones de una cuenta
./ledger transacciones -c1=alice -c2=alice

# Transferencias de alice a bob
./ledger transacciones -c1=alice -c2=bob

# Transacciones en USD
./ledger transacciones -m=USD

# Desde archivo CSV
./ledger transacciones -t=data/transacciones.csv -c1=alice

# Guardar en archivo
./ledger transacciones -c1=alice -o=trans_output.csv
```

## 💡 Ejemplos de Uso

### Escenario completo: Sistema de pagos entre usuarios

```bash
# 1. Crear usuarios
./ledger crear_usuario -n=alice -b=1995-06-15
./ledger crear_usuario -n=bob -b=1998-03-20
./ledger crear_usuario -n=charlie -b=1992-11-10

# 2. Crear monedas
./ledger crear_moneda -n=USD -p=1.0000
./ledger crear_moneda -n=EUR -p=1.0800
./ledger crear_moneda -n=BTC -p=45000.0000

# 3. Dar de alta monedas en cuentas (depósito inicial)
./ledger alta_cuenta -u=1 -m=1 -a=5000    # Alice: 5000 USD
./ledger alta_cuenta -u=1 -m=2 -a=2000    # Alice: 2000 EUR
./ledger alta_cuenta -u=2 -m=1 -a=3000    # Bob: 3000 USD

# 4. Transferencias
./ledger realizar_transferencia -o=1 -d=2 -m=1 -a=500
# Alice transfiere 500 USD a Bob

# 5. Swap de monedas
./ledger realizar_swap -u=1 -mo=1 -md=2 -a=1000
# Alice intercambia 1000 USD por EUR

# 6. Consultar balances
./ledger balance -c1=alice
# Ver balance completo de Alice

./ledger balance -c1=alice -m=USD
# Ver balance de Alice en USD

# 7. Ver historial de transacciones
./ledger transacciones -c1=alice -c2=alice
# Todas las transacciones de Alice

# 8. Exportar reportes
./ledger balance -c1=alice -o=reporte_alice.csv
./ledger transacciones -c1=alice -o=historial_alice.csv

# 9. Deshacer última transacción (si es necesario)
./ledger deshacer_transaccion -id=10
```

### Ejemplo con archivos CSV

```bash
# Consultar transacciones desde archivo CSV
./ledger transacciones -t=data/transacciones.csv -c1=alice -m=USD -o=resultado.csv

# Consultar balance usando archivo de transacciones
./ledger balance -c1=alice -t=data/transacciones.csv -m=EUR
```

### Módulos principales documentados

- `Ledger` - Orquestador principal del sistema
- `Argumentos` - Validación de argumentos CLI
- `Ledger.Usuario` - Gestión de usuarios
- `Ledger.Moneda` - Gestión de monedas
- `Ledger.Transaccion` - Gestión de transacciones
- `Estructuras.Balance` - Cálculo de balances
- `Estructuras.Transaccion` - Consultas de transacciones
- `CSVManager` - Manejo de archivos CSV
- `Herramientas` - Utilidades y helpers

## 🛠️ Comandos útiles (Makefile)

```bash
make init                # Iniciar el proyecto

make docker-up           # Iniciar PostgreSQL
make docker-down         # Detener PostgreSQL

make psql-dev            # Entrar a la terminal de psql de la base de datos del proyecto
make psql-test           # Entrar a la terminal de psql de la base de datos test

make test                # Correr los tests
make reload              # Reinicia la base de datos 
```

Después de ejecutar `make reload`, la base de datos se reiniciará. Para poblar la base de datos con datos de prueba, copiar y pegar los siguientes comandos en la terminal:

```bash
./ledger crear_usuario -n=usuario1 -b=2003-07-14
./ledger crear_usuario -n=usuario2 -b=2001-05-09
./ledger crear_usuario -n=usuario3 -b=1999-12-02
./ledger crear_usuario -n=usuario4 -b=2005-03-28
./ledger crear_usuario -n=usuario5 -b=2000-10-17

./ledger crear_moneda -n=USD -p=1.0000
./ledger crear_moneda -n=LUM -p=0.5823
./ledger crear_moneda -n=ARKA -p=2.1390
./ledger crear_moneda -n=VEX -p=0.9417
./ledger crear_moneda -n=ORIN -p=3.2745

./ledger alta_cuenta -u=1 -m=1 -a=10000
./ledger alta_cuenta -u=1 -m=2 -a=5000
./ledger alta_cuenta -u=2 -m=1 -a=7500
./ledger alta_cuenta -u=2 -m=3 -a=0.5
./ledger alta_cuenta -u=3 -m=2 -a=8000
./ledger alta_cuenta -u=3 -m=1 -a=12000
./ledger realizar_transferencia -o=1 -d=2 -m=1 -a=1500
./ledger realizar_transferencia -o=2 -d=3 -m=1 -a=2000
./ledger realizar_transferencia -o=1 -d=3 -m=2 -a=1000
./ledger realizar_swap -u=1 -mo=1 -md=2 -a=2000
./ledger realizar_transferencia -o=3 -d=1 -m=1 -a=3000
./ledger alta_cuenta -u=1 -m=3 -a=0.25
./ledger realizar_swap -u=2 -mo=1 -md=3 -a=1000
./ledger realizar_transferencia -o=3 -d=2 -m=2 -a=2500
./ledger realizar_transferencia -o=1 -d=2 -m=3 -a=0.1
```

## ⚠️ Manejo de Errores

El sistema implementa validaciones exhaustivas en todas las operaciones:

### Validación de argumentos
- ❌ Flags inválidos para la operación
- ❌ Flags duplicados
- ❌ Flags sin valor asignado
- ❌ Operación no válida (con sugerencias inteligentes)
- ❌ Flags obligatorios faltantes

### Validación de usuarios
- ❌ Usuario menor de 18 años
- ❌ Username duplicado
- ❌ Username muy corto/largo (5-20 caracteres)
- ❌ Eliminar usuario con transacciones

### Validación de monedas
- ❌ Nombre duplicado
- ❌ Nombre no en mayúsculas
- ❌ Nombre incorrecto (3-4 caracteres)
- ❌ Precio negativo
- ❌ Eliminar moneda usada en transacciones

### Validación de transacciones
- ❌ Fondos insuficientes
- ❌ Monedas iguales en swap
- ❌ Cuentas iguales en transferencia
- ❌ Moneda no dada de alta en cuenta
- ❌ Deshacer transacción que no es la última
- ❌ Balances negativos

### Ejemplo de error con sugerencia

```bash
./ledger balanc -c1=alice
# Error: "Quisiste decir balance"

./ledger balance -c1=alice -c2=bob
# Error: "En la operacion de balance el flag -c2 no esta permitido"
```

## 🔒 Características de Seguridad

- ✅ Validación de tipos de datos con Ecto
- ✅ Constraints de base de datos (unique, foreign keys)
- ✅ Validación de edad (mayores de 18)
- ✅ Validación de fondos suficientes
- ✅ Prevención de eliminación de datos referenciados
- ✅ Validación de formato de datos (fechas, decimales)
- ✅ Manejo seguro de operaciones concurrentes con transacciones DB
