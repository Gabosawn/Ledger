defmodule Estructuras.Moneda do
  @moduledoc """
  Módulo para gestionar la información de monedas en el sistema Ledger.

  Este módulo proporciona funcionalidades para:
  - Definir la estructura de datos de una moneda
  - Obtener información de monedas desde la base de datos
  - Consultar precios de monedas en USD

  ## Estructura de datos

  Cada moneda contiene:
  - `nombre_moneda` - Código o nombre de la moneda (ej: USD, EUR, BTC)
  - `precio_usd` - Precio de la moneda expresado en dólares estadounidenses

  ## Uso

  Este módulo se utiliza principalmente para:
  - Conversiones entre diferentes monedas
  - Cálculos de balances multi-moneda
  - Operaciones de swap entre monedas

  ## Ejemplos

      # Obtener todas las monedas disponibles
      iex> Estructuras.Moneda.obtenerMonedas()
      [
        %Estructuras.Moneda{nombre_moneda: "USD", precio_usd: 1.0},
        %Estructuras.Moneda{nombre_moneda: "EUR", precio_usd: 1.08},
        %Estructuras.Moneda{nombre_moneda: "BTC", precio_usd: 45000.0}
      ]
  """

  import Ecto.Query

  @headers [:nombre_moneda, :precio_usd]
  defstruct @headers

  @doc """
  Retorna los headers (campos) disponibles para la estructura de moneda.

  ## Retorna

  Una lista con los átomos que representan los campos de la estructura:
  - `:nombre_moneda` - Código o nombre de la moneda
  - `:precio_usd` - Precio de la moneda en dólares USD

  ## Ejemplos

      iex> Estructuras.Moneda.getHeaders()
      [:nombre_moneda, :precio_usd]
  """
  def getHeaders do
    @headers
  end

  @doc """
  Obtiene todas las monedas disponibles desde la base de datos.

  Esta función consulta la tabla de monedas en la base de datos y retorna
  una lista de estructuras `Estructuras.Moneda` con la información de cada
  moneda disponible en el sistema.

  ## Retorna

  Lista de estructuras `%Estructuras.Moneda{}` con:
  - `nombre_moneda` - Nombre/código de la moneda
  - `precio_usd` - Precio actual en dólares estadounidenses

  ## Ejemplos

      iex> Estructuras.Moneda.obtenerMonedas()
      [
        %Estructuras.Moneda{nombre_moneda: "USD", precio_usd: 1.0},
        %Estructuras.Moneda{nombre_moneda: "EUR", precio_usd: 1.08},
        %Estructuras.Moneda{nombre_moneda: "GBP", precio_usd: 1.25}
      ]

      # Si no hay monedas en la base de datos
      iex> Estructuras.Moneda.obtenerMonedas()
      []
  """
  def obtenerMonedas do
    Ledger.Moneda
    |> select([m], %Estructuras.Moneda{nombre_moneda: m.nombre, precio_usd: m.precio_dolar})
    |> Ledger.Repo.all()
  end
end
