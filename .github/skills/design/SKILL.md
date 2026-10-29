---
name: design
description: "Diseña planes pytest función por función con caja blanca, caja negra, EP, BVA, ramas, parametrización y trazabilidad para tests/testplans."
---
# Instrucciones Principales
Actúas como un ingeniero de calidad de software (QA) experto. Tu objetivo es generar planes de prueba estructurados analizando el código o los requisitos proporcionados por el usuario, **función por función, sin excepción**.

## Contrato de entrada y salida
- Entrada: un archivo Python existente y los requisitos del usuario.
- Salida exclusiva: `tests/testplans/{paquete}/plan_{nombre_de_la_clase}.md`.
- Lee el archivo fuente completo antes de diseñar.
- No escribas código Python, no edites código de producción y no crees tests en esta fase.
- Analiza todas las funciones y métodos definidos, incluidos los privados, excepto `__init__`.

## PRINCIPIO FUNDAMENTAL
**Cada función del archivo recibe su propio bloque de análisis completo.** Ese bloque SIEMPRE contiene:
1. Una tabla de **Caja Blanca** con cobertura de líneas Y ramas.
2. Una tabla de **Caja Negra** con Particionamiento de Equivalencia (EP) Y Valores Límite (BVA).

Ninguna función puede tener solo una de las dos tablas, salvo la excepción documentada al final.

## FLUJO DE TRABAJO OBLIGATORIO (POR CADA FUNCIÓN)

### FASE 1 — Caja Blanca: Cobertura de Líneas y Ramas
**Objetivo:** Garantizar el 100% de **Line Coverage** y **Branch Coverage**.

**Paso 1 — Line Coverage:** Diseña el caso mínimo que ejecuta el camino principal (happy path) de la función completa, de inicio a fin, sin omitir ninguna línea.

**Paso 2 — Branch Coverage:** Para cada decisión (`if`, `elif`, `else`, `try/except`, operador ternario, `and`/`or` en guards), diseña un caso para la rama `True` y un caso para la rama `False`. Cada fila de esta sub-tabla debe indicar qué rama específica activa.

**Aislamiento:** Identifica toda dependencia externa (BD, HTTP, ficheros, tiempo). Estas dependencias se mockearán; los casos deben describir el comportamiento esperado del mock.

### FASE 2 — Caja Negra: EP y BVA
**Objetivo:** Probar el contrato público de la función desde la perspectiva del usuario, independientemente de la implementación interna.

**Paso 1 — Equivalence Partitioning (EP):** Divide el dominio de cada parámetro en clases de equivalencia (válidas e inválidas). Diseña al menos un caso representativo por clase.

**Paso 2 — Boundary Value Analysis (BVA):** Para cada rango o límite identificado, diseña casos en el valor exacto del límite, inmediatamente por debajo y inmediatamente por encima (min-1, min, min+1 / max-1, max, max+1).

> **NOTA SOBRE SOLAPAMIENTO:** Un valor límite puede coincidir con una condición ya cubierta en Caja Blanca, y eso está PERMITIDO. Las dos tablas tienen perspectivas diferentes (estructura interna vs. contrato externo). Lo único prohibido es duplicar una fila con exactamente el mismo propósito técnico y el mismo input dentro de la misma tabla.

### FASE 3 — Preparación para Parametrización
Revisa ambas tablas y agrupa las filas que puedan convertirse a `@pytest.mark.parametrize`. Indica en una nota al final de cada sección qué grupos son candidatos a parametrización.

## FORMATO DE SALIDA OBLIGATORIO (POR FUNCIÓN)

Usa estrictamente esta estructura para cada función:

```
---
## Función `N`: `nombre_funcion`

### CAJA BLANCA — Cobertura de Líneas y Ramas

| ID                                                                    | Descripción                                                        | Tipo           | Condición / Línea             | Input                  | Expected Output          |
|-----------------------------------------------------------------------|--------------------------------------------------------------------|----------------|-------------------------------|------------------------|--------------------------|
| [test_1_Clase_nombre_funcion](../../tests/{paquete}/test_Clase.py)    | Verifica que la función completa se ejecuta con datos válidos      | Line Coverage  | Camino completo               | param=valor_valido     | resultado_esperado       |
| [test_2_Clase_nombre_funcion](../../tests/{paquete}/test_Clase.py)    | Verifica que la rama verdadera de `if condicion` devuelve X        | Branch TRUE    | `if condicion` → rama True    | param=valor_true       | resultado_esperado       |
| [test_3_Clase_nombre_funcion](../../tests/{paquete}/test_Clase.py)    | Verifica que la rama falsa de `if condicion` devuelve Y            | Branch FALSE   | `if condicion` → rama False   | param=valor_false      | resultado_esperado       |

### CAJA NEGRA — EP y Valores Límite

| ID                                                                    | Descripción                                                        | Técnica        | Clase / Límite                | Input                  | Expected Output          |
|-----------------------------------------------------------------------|--------------------------------------------------------------------|----------------|-------------------------------|------------------------|--------------------------|
| [test_4_Clase_nombre_funcion](../../tests/{paquete}/test_Clase.py)    | Verifica que una entrada válida es aceptada y procesada            | EP Válida      | Descripción de la clase       | param=valor_valido     | resultado_esperado       |
| [test_5_Clase_nombre_funcion](../../tests/{paquete}/test_Clase.py)    | Verifica que una entrada inválida lanza el error esperado          | EP Inválida    | Descripción de la clase       | param=valor_invalido   | excepción/error          |
| [test_6_Clase_nombre_funcion](../../tests/{paquete}/test_Clase.py)    | Verifica el comportamiento exactamente en el límite inferior       | BVA Límite     | Límite inferior exacto        | param=limite_min       | resultado_esperado       |
| [test_7_Clase_nombre_funcion](../../tests/{paquete}/test_Clase.py)    | Verifica que un valor por debajo del límite es rechazado           | BVA Límite-1   | Por debajo del límite         | param=limite_min - 1   | excepción/error          |

> Candidatos a parametrización: IDs test_4_Clase_nombre_funcion, test_5_Clase_nombre_funcion, test_6_Clase_nombre_funcion, test_7_Clase_nombre_funcion
---
```

## SISTEMA DE IDs — FORMATO `test_M_Clase_funcion`
- El ID de cada caso de prueba **es exactamente el nombre de la función pytest** que lo implementará, siguiendo el formato: `test_{M}_{Clase}_{nombre_funcion}`.
  - `M` = número secuencial del caso dentro de esa función (1, 2, 3…), compartido entre Caja Blanca y Caja Negra.
  - `Clase` = nombre de la clase bajo prueba (en PascalCase, sin espacios).
  - `nombre_funcion` = nombre de la función bajo prueba (en snake_case).
- Ejemplo para la función `create_user` de la clase `UserService`: `test_1_UserService_create_user`, `test_2_UserService_create_user`, `test_3_UserService_create_user`…
- Cada función comienza su contador `M` desde 1 de forma independiente.
- **Ningún ID puede repetirse en todo el documento** (la combinación `M + Clase + funcion` garantiza unicidad entre funciones distintas).
- **Los IDs son enlaces Markdown con trazabilidad a línea.** Mientras el test no exista, el plan puede usar solo la ruta (`[test_1_UserService_create_user](../../tests/{paquete}/test_Clase.py)`). En cuanto se genere el test, el enlace debe actualizarse obligatoriamente con `#L<línea>` apuntando a la línea exacta de su declaración `def test_...` (`[test_1_UserService_create_user](../../tests/{paquete}/test_Clase.py#L42)`).
- **El plan final no puede contener enlaces sin número de línea ni números de línea aproximados.** Antes de entregarlo, debe comprobarse que cada ID aparece en el archivo de test y que su ancla `#L<línea>` coincide con la línea donde comienza la función pytest con ese mismo nombre. Si el test está parametrizado, se enlaza la línea de la única función `def test_...` que contiene los casos.
- **Trazabilidad directa:** el ID del plan es el nombre literal de la función en el código de test, y su enlace lleva directamente a la declaración de esa función, permitiendo navegar del plan al test y viceversa sin ambigüedad.

## Criterios de aceptación del plan
Antes de finalizar, comprueba todos los puntos siguientes:
1. El inventario coincide exactamente con las funciones del archivo fuente, salvo `__init__`.
2. Cada función tiene una sección propia, una tabla de Caja Blanca y una tabla de Caja Negra.
3. Cada decisión interna tiene ramas True y False, salvo que se documente por qué no existe una de ellas.
4. Cada parámetro tiene clases EP y límites BVA aplicables; si no hay límite numérico, usa vacío, `None`, longitud o límites de negocio.
5. Cada fila tiene un ID único, una descripción accionable, input y resultado esperado.
6. Los enlaces preliminares apuntan a `../../tests/{paquete}/test_{nombre_de_la_clase}.py`; después de implementar, deben incluir `#LXX`.
7. El plan no contiene nombres inventados ni tablas compartidas por varias funciones.

## REGLAS CRÍTICAS DE EJECUCIÓN
- **COMPLETITUD OBLIGATORIA:** Cada función tiene que tener ambas tablas. No se puede omitir ninguna tabla sin documentar explícitamente la razón (ver Solución de Problemas).
- **IDs ÚNICOS:** Usa siempre el formato `test_M_Clase_funcion`. Nunca uses números simples (`1`, `2`, `3`) ni el formato jerárquico antiguo (`N.M`).
- **SIN CÓDIGO:** Solo genera el plan en lenguaje natural y tablas. NUNCA escribas código Python en esta fase.
- **UBICACIÓN:** Escribe exclusivamente en `tests/testplans/{paquete}/plan_{nombre_de_la_clase}.md`.
- **PRECISIÓN SOBRE VELOCIDAD:** Analiza cada función de forma independiente. No agrupas varias funciones en un mismo bloque.
- **ENLACES FINALES:** Tras la implementación de los tests, sustituye todos los enlaces preliminares por enlaces con la línea exacta de cada `def test_<ID>` antes de considerar completada la trazabilidad.

## Solución de Problemas

| Situación | Acción |
|-----------|--------|
| La función no tiene ramas (`if`/`else`) | En la tabla de Caja Blanca escribe solo la fila de Line Coverage e indica: *"Sin ramas lógicas — solo camino principal"*. La tabla de Caja Negra es obligatoria igualmente. |
| El parámetro no tiene límites numéricos obvios | En BVA analiza límites de longitud de cadena, valores `None`/vacío, o límites impuestos por la lógica de negocio. |
| La función delega toda la lógica a otra | Documenta el mock necesario y diseña casos que verifiquen que la delegación ocurre correctamente (llamada con args correctos, manejo del valor de retorno, manejo de excepción). |