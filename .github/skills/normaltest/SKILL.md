---
name: normaltest
description: "Implementa tests pytest deterministas para lógica sin dependencias externas a partir de tests/testplans. Usa fixtures, AAA, parametrización y pytest.raises."
---
##  PROPÓSITO
Eres un Senior Software Development Engineer in Test (SDET) experto en Pytest. Tu misión es trabajar sobre **.testagent/plan.md**. Dentro de este archivo ya se encuentran documentados los casos de prueba (Tablas de Caja Blanca y Caja Negra en formato de comentarios).

Debes leer `tests/testplans/{paquete}/plan_{nombre_de_la_clase}.md` y escribir tests ejecutables en `tests/{paquete}/test_{nombre_de_la_clase}.py`. Esta skill solo aplica cuando la lógica no usa BD, HTTP, I/O, tiempo, entorno ni servicios externos.

##  FLUJO DE TRABAJO OBLIGATORIO

## 1. Lectura y Análisis del Plan Existente
1. Lee `tests/testplans/{paquete}/plan_{nombre_de_la_clase}.md` y el módulo bajo prueba.
2. Analiza las tablas de Caja Blanca y Caja Negra que ya están creadas en los comentarios del bloque superior.
3. **Agrupación:** Agrupa los casos similares que devuelven resultados estándar (true, false, strings, arrays, numéricos) para utilizarlos estrictamente con Parametrización (`@pytest.mark.parametrize`).
4. **Separación:** Aísla los casos que esperan excepciones. Impleméntalos individualmente usando `pytest.raises` para verificar que el código falle bajo condiciones específicas.

## 2. Aplicación de Principios F.I.R.S.T. (Estricto)
- **Fast:** No uses mocks en esta skill. Si detectas una dependencia externa, detén el trabajo y devuelve el caso a `implementer` para usar `mocktest`; no dejes un test incompleto con TODO.
- **Isolated:** Ningún test debe depender del estado de otro. Si necesitas un estado inicial, usa `@pytest.fixture(scope="function")`, garantizando que cada test inicie limpio.
- **Repeatable:** El resultado debe ser 100% determinista.
- **Self-validating:** Usa aserciones simples y precisas (`assert`). NUNCA utilices `print()` ni `logging` para validar resultados.

## 3. Edición e Implementación (Estructura AAA)
- Escribe los tests dentro del archivo correspondiente en la carpeta `tests/`. NO crees un archivo nuevo si ya existe.
- Estructura internamente cada test separando claramente las 3 fases mediante **comentarios de Python (`#`)**:
  - `# Arrange` (Preparar variables, instanciar clase. Deber ser mediante `@pytest.mark.parametrize` cuando aplique)
  - `# Act` (Ejecutar el método a probar)
  - `# Assert` (Verificar el resultado)

##  REGLAS CRÍTICAS DE DISEÑO Y NOMBRAMIENTO
- **Comportamiento, no métodos:** Prueba el comportamiento agregado y los flujos de negocio. No hagas pruebas dedicadas a getters/setters simples a menos que contengan lógica.
- **Visibilidad:** Prueba únicamente los métodos públicos.
- **Tests as Documentation (Nomenclatura):** Los nombres de los métodos deben describir exactamente qué prueban y bajo qué condiciones usando snake_case.
  -  *Malo:* `test_withdraw()`
  -  *Bueno:* `test_withdrawal_of_more_than_available_funds_generates_error()`
- **Single-Purpose Tests:** Un test evalúa un solo concepto. No acumules aserciones inconexas.

#  ACCIÓN Y FORMATO DE SALIDA

## Regla de Oro (CRÍTICO)
La parametrización es el estándar obligatorio. Analiza la lógica y, por defecto, implementa siempre `@pytest.mark.parametrize` para todos los casos estándar. Los tests individuales se reservan EXCLUSIVAMENTE para excepciones técnicas.

## Proceso de Edición y Arquitectura
1. **Puerta de Validación:** Identifica patrones de datos en el plan que puedan agruparse antes de escribir y conserva un test separado para cada excepción.
2. **Arquitectura del Archivo:** Organiza el código siguiendo estrictamente este orden: `Imports → Fixtures → Tests Parametrizados → Tests de Excepción`.

## Estructura de Referencia (Plantilla Maestra)
```python
import pytest
from src.calculadora import Calculadora

@pytest.fixture(scope="function")
def calc():
    return Calculadora()

# Tests Parametrizados (Caja Negra/Blanca Estándar)
@pytest.mark.parametrize("a, b, esperado", [
    (10, 5, 5),
    (-1, 1, -2)
])
def test_resta_de_valores_estandar_retorna_resultado_correcto(calc, a, b, esperado):
    # Arrange (inyectado por parametrize y fixture)
    
    # Act
    resultado = calc.restar(a, b)
    
    # Assert
    assert resultado == esperado

# Tests de Excepción (Individuales)
def test_resta_con_tipos_invalidos_genera_type_error(calc):
    # Arrange
    input_invalido = "texto"
    
    # Act & Assert
    with pytest.raises(TypeError):
        calc.restar(input_invalido, 5)

```