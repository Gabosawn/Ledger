defmodule ArgumentosTest do
  use ExUnit.Case

  alias Ledger.Transaccion, as: Transaccion
  alias Estructuras.Argumentos, as: Arg
  alias Ledger.Usuario, as: Usuario
  alias Ledger.Moneda, as: Moneda
  alias Ledger.Repo

  setup do
    # Explicitly get a connection before each test
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
  end

  test "No hay texto" do
    res = Argumentos.validationArgs([])
    expected = {:error, "No se ha proporcionado ningun parámetro"}

    assert res == expected
  end

  test "Error, mal escritas las operaciones sin coincidir en nada" do
    operaciones = [Moneda.getHeaders().operaciones, Transaccion.getHeaders().operaciones, Arg.getHeaders().operaciones, Usuario.getHeaders().operaciones]
    |> List.flatten()

    responses = Enum.map(operaciones, fn operacion ->
      input = String.upcase(operacion)
      Argumentos.validationArgs([input])
    end)

    expected = Enum.map(operaciones, fn _ ->
      {:error, "Escribir primero el tipo de operacion"}
    end)

    assert responses == expected
  end

  test "Error, mal escritas las operaciones" do
    operaciones = [Moneda.getHeaders().operaciones, Transaccion.getHeaders().operaciones, Arg.getHeaders().operaciones, Usuario.getHeaders().operaciones]
    |> List.flatten()
    responses = Enum.map(operaciones, fn operacion ->
      input = String.capitalize(operacion)
      Argumentos.validationArgs([input])
    end)

    expected = Enum.map(operaciones, fn operacion ->
      {:error, "Quisiste decir #{operacion}"}
    end)

    assert responses == expected
  end

  test "Error, no hay flags en las operaciones, exceptuando transacciones" do
    operaciones = [Moneda.getHeaders().operaciones, Transaccion.getHeaders().operaciones, Arg.getHeaders().operaciones, Usuario.getHeaders().operaciones]
    |> List.flatten() |> Enum.reject(fn op -> op == "transacciones" end)

    responses = Enum.map(operaciones, fn operacion ->
      Argumentos.validationArgs([operacion])
    end)

    expected = Enum.map(operaciones, fn _ ->
      {:error, "No se ha proporcionado ningun flag"}
    end)

    assert responses == expected
  end

  test "Error, hay flags que no son perminitos en las operaciones de moneda" do
    operaciones = [Moneda.getHeaders().operaciones]
    |> List.flatten()

    responses = Enum.map(operaciones, fn operacion ->
      Argumentos.validationArgs([operacion, "-x=cuatro"])
    end)

    expected = Enum.map(operaciones, fn _ ->
      {:error, "Flags invalidos. Los que se pueden usar son: -id, -n, -p"}
    end)

    assert responses == expected
  end

  test "Error, hay flags que no son perminitos en las operaciones de usuario" do
    operaciones = [Usuario.getHeaders().operaciones]
    |> List.flatten()

    responses = Enum.map(operaciones, fn operacion ->
      Argumentos.validationArgs([operacion, "-x=cuatro"])
    end)

    expected = Enum.map(operaciones, fn _ ->
      {:error, "Flags invalidos. Los que se pueden usar son: -id, -n, -b"}
    end)

    assert responses == expected
  end

  test "Error, hay flags que no son perminitos en las operaciones de transaccion" do
    operaciones = [Transaccion.getHeaders().operaciones]
    |> List.flatten()

    responses = Enum.map(operaciones, fn operacion ->
      Argumentos.validationArgs([operacion, "-x=cuatro"])
    end)

    assert Enum.all?(responses, fn {status, response} -> status == :error end)
  end

  test "Error, hay flags que no son permitidos en las operaciones de transacciones y balance" do
    operaciones = [Arg.getHeaders().operaciones]
    |> List.flatten()

    responses = Enum.map(operaciones, fn operacion ->
      Argumentos.validationArgs([operacion, "-x=cuatro"])
    end)

    assert Enum.all?(responses, fn {status, response} -> status == :error end)
  end

  test "Error, los flags en las cualquier operacion moneda estan vacios" do
    responses = Argumentos.validationArgs(["crear_moneda", "-id" ,"-n", "-p"])

    expected = {:error, "El flag -id no tiene ningun valor"}

    assert responses == expected
  end

  test "Error, los flags en las cualquier operacion usuario estan vacios" do
    responses = Argumentos.validationArgs(["crear_usuario", "-id" ,"-n", "-b"])

    expected = {:error, "El flag -id no tiene ningun valor"}

    assert responses == expected
  end

  test "Error, los flags en las cualquier operacion transaccion estan vacios" do
    responses = Argumentos.validationArgs(["realizar_transferencia", "-o" ,"-d", "-a"])

    expected = {:error, "El flag -o no tiene ningun valor"}

    assert responses == expected
  end

  test "Error, los flags en las cualquier operacion transacciones y balance estan vacios" do
    responses = Argumentos.validationArgs(["transacciones", "-c1"])

    expected = {:error, "El flag -c1 no tiene ningun valor"}

    assert responses == expected
  end

  test "Error, los flags en las cualquier operacion esta duplicado" do
    res = Argumentos.validationArgs(["crear_moneda", "-n=USD", "-n=USD"])
    expected = {:error, "Algún flag se encuentra duplicado"}

    assert res == expected
  end


  test "Error, faltan flags en las operaciones  transaccion" do
    res = [
      Argumentos.validationArgs(["alta_cuenta", "-m=1"]),
      Argumentos.validationArgs(["realizar_swap", "-mo=1", "-md=2"]),
      Argumentos.validationArgs(["realizar_transferencia", "-o=1", "-d=2"])
    ]

    expected = [
      {:error, "La operacion alta_cuenta debe tener los flags -u, -m"},
      {:error, "La operacion realizar_swap debe tener los flags -mo, -md, -u"},
      {:error, "La operacion realizar_transferencia debe tener los flags -o, -d, -m"}
    ]

    assert res == expected
  end

  test "Ok, las operaciones pasan todos los filtros" do
    res = Argumentos.validationArgs(["crear_usuario", "-n=testargs", "-b=2003-07-14"])

    expected = {:ok, "Operación realizada con exito"}

    assert res == expected
  end
end
