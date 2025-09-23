defmodule ArgumentosTest do
    use ExUnit.Case
    doctest Argumentos
   
    test "No hay texto" do 
        res = Argumentos.validationArgs([])
        expected = {:error, "No se ha proporcionado ningun parámetro"}

        assert res == expected
    end

    test "Se escriben mal la operacion, sin coincidir nada" do
        res = Argumentos.validationArgs(["error"])
        expected = {:error, "Escribir primero el tipo de operacion: balance  o transacciones"}

        assert res == expected
    end

    test "Se escribe mal la operacion transaccion" do
        res = Argumentos.validationArgs(["transacion"])
        expected = {:error, "Quisiste decir transacciones"}

        assert res == expected
    end

    test "Se escribe mal la operacion balance" do
        res = Argumentos.validationArgs(["balace"])
        expected = {:error, "Quisiste decir balance"}

        assert res == expected
    end

    test "No hay flags en la operacion balance" do
        res = Argumentos.validationArgs(["balance"])
        expected = {:error, "No se ha proporcionado ningun flag"}

        assert res == expected
    end

    test "En cualquier operacion se escriben mal los flags" do
        res1 = Argumentos.validationArgs(["transacciones", "-k=USD"])
        res2 = Argumentos.validationArgs(["balance", "-h=USD"])

        expected = {:error, "Flags invalidos. Los que se pueden usar son: -c1=origen -c2=destino -t=input -m=moneda -o=output"}
        
        assert res1 == expected
        assert res2 == expected
    end
    
    test "Los flags en cualquier operacion estan duplicados" do
        res1 = Argumentos.validationArgs(["transacciones", "-c1=USD", "-c1=USD"])
        res2 = Argumentos.validationArgs(["balance", "-c1=USD", "-c1=ARS"])

        expected = {:error, "Algún flag se encuentra duplicado"}
        
        assert res1 == expected
        assert res2 == expected
    end


    test "Existe algun flag sin valor en cualquier operacion" do
        res1 = Argumentos.validationArgs(["transacciones", "-c1="])
        res2 = Argumentos.validationArgs(["balance", "-c1="])

        expected = {:error, "El flag -c1 no tiene ningun valor"}
        
        assert res1 == expected
        assert res2 == expected
    end

    test "La operacion balance no tiene el flag de -c1 obligatorio" do
        res = Argumentos.validationArgs(["balance", "-m=USD"])

        expected = {:error, "En la operacion de balance es obligatorio poner el flag -c1"}
        
        assert res == expected
    end

    test "La operacion balance tiene el flag de -c2" do
        res = Argumentos.validationArgs(["balance", "-c1=gabo", "-c2=pedro"])

        expected = {:error, "En la operacion de balance el flag -c2 no esta permitido"}
        
        assert res == expected
    end

end