# Proyecto 2: juego de reflejos sobre Pochoco SoC

Arquitectura de Computadores — Grupo 18

Juego de reflejos implementado en assembly sobre el procesador Espino Core y Pochoco SoC, para la FPGA Lattice iCE40 HX1K de la Nandland Go Board. El proyecto incluye el programa, un assembler propio en Python, las modificaciones al RTL y las pruebas automatizadas.

## Funcionamiento

Cada ronda comienza con los cuatro LEDs encendidos durante al menos tres segundos. Después de una liberación estable de los botones durante 20 ms, se selecciona un LED objetivo y comienza la medición de respuesta.

Una pulsación correcta suma un acierto y muestra el tiempo durante un segundo. Una pulsación incorrecta, incluyendo una máscara con varios botones, muestra `EE` y repite la ronda sin modificar los aciertos ni la suma acumulada. Después de diez respuestas correctas se muestra el promedio. Una nueva pulsación y su liberación reinician la partida.

Los tiempos se expresan en décimas de segundo: `07` representa 0,7 s y `12` representa 1,2 s. Los displays no utilizan punto decimal. La visualización satura en `99`; la suma interna conserva el tiempo cuantizado completo.

## Arquitectura

`rtl/game_top.v` es el módulo superior de síntesis. Instancia Pochoco SoC con la imagen `sw/game.hex` y el controlador SPI desactivado mediante `EnableSPI=0`.

- Espino Core: procesador de 32 bits con registros `x0` a `x15`. El programa evita desplazamientos, multiplicación y división, no disponibles para este juego.
- RAM unificada: 512 palabras de 32 bits, equivalentes a 2048 bytes. El programa ocupa 99 palabras, o 396 bytes.
- Periféricos MMIO: LEDs, botones sincronizados, displays, contador libre y captura de respuesta.
- Inicialización: reset de 65535 ciclos y escritura explícita de cero en `x0` de ambos bancos durante el reset. En ejecución normal, las escrituras a `x0` permanecen bloqueadas.

El reloj opera a 25 MHz. La escritura que enciende el LED objetivo captura el contador en el mismo flanco lógico. La primera muestra sincronizada no nula de botones almacena el tiempo transcurrido y su máscara; el software consulta posteriormente la bandera de captura.

## Estructura del repositorio

```text
rtl/
  game_top.v              Módulo superior para la Go Board
  pochoco_soc.v           Interconexión y reset
  pochoco_ram.v           Memoria unificada
  pochoco_periph.v        Periféricos y medición de tiempo
  pochoco_spi_slave.v     Componente opcional del SoC base
  espino_core/            Módulos del procesador

sw/
  game.s                  Programa del juego
  game.hex                Imagen de instrucciones
tools/
  assembler.py            Assembler propio
tests/
  test_assembler.py       Codificación y validación
  simulate.py             Preparación y ejecución de la simulación
  tb_game.v               Test bench del SoC
build.ps1                 Construcción en Windows PowerShell
Makefile                  Construcción con GNU Make
goboard.pcf              Asignación de pines de la placa
```

## Requisitos de construcción

El flujo de construcción utiliza Python 3 y OSS CAD Suite. Las herramientas `python`, `yosys`, `nextpnr-ice40`, `icepack` e `iceprog` deben estar disponibles en el PATH. Las pruebas de simulación requieren además `iverilog` y `vvp`.

`build.ps1` localiza Yosys y agrega el directorio `lib` de su instalación al entorno del proceso para cargar las dependencias de OSS CAD Suite. Los comandos se ejecutan desde la raíz del repositorio.

## Ensamblado, síntesis y programación

Regeneración de `sw/game.hex` a partir de `sw/game.s`:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\build.ps1 assemble
```

El assembler también admite ejecución directa:

```powershell
python tools/assembler.py sw/game.s sw/game.hex
```

Síntesis, ubicación, ruteo y generación del bitstream:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\build.ps1 build
```

Construcción y programación de la Go Board conectada por USB:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\build.ps1 program
```

El flujo regenera la imagen de instrucciones, sintetiza `game_top` con Yosys, ejecuta NextPNR para `hx1k/vq100` con objetivo de 25 MHz y genera `build/game.bin` mediante Icepack. La acción `program` también escribe y verifica la Flash mediante Iceprog.

La versión de Yosys utilizada presentó un fallo interno con ABC9. El script emplea ABC clásico para el mapeo a LUTs de cuatro entradas y guarda los comandos en `build/synth.ys`, evitando problemas de comillas en rutas con espacios bajo Windows PowerShell.

En entornos con GNU Make y un shell compatible, los objetivos equivalentes son `make assemble`, `make test`, `make all` y `make prog`.

## Assembler

`tools/assembler.py` traduce el programa sin invocar un assembler RISC-V externo. Genera una palabra de 32 bits con ocho caracteres hexadecimales por línea y un archivo auxiliar `game.symbols.json` con símbolos y constantes.

La sintaxis admite registros `x0` a `x15`, inmediatos decimales, hexadecimales y negativos, comentarios `#`, etiquetas y constantes `.equ`. Las instrucciones soportadas son:

- Operaciones de registro: `add`, `sub`, `xor`, `or`, `and`, `slt`, `sltu`.
- Operaciones inmediatas: `addi`, `xori`, `ori`, `andi`, `slti`, `sltiu`.
- Memoria y carga de inmediato: `lw`, `sw`, `lui`.
- Control: `jal`, `jalr`, `beq`, `bne`, `blt`, `bge`, `bltu`, `bgeu`.
- Pseudoinstrucción `li`, expandida siempre a `lui` y `addi`.

El ensamblado utiliza dos pasadas para resolver etiquetas. En branches y saltos, una etiqueta representa un destino cuya dirección se convierte a desplazamiento relativo al PC; un número representa directamente un desplazamiento. Se comprueban registros, operandos, instrucciones, símbolos, rangos de inmediatos, alineación y capacidad de memoria.

Ejemplo: `lw x9, 12(x2)` se codifica como `00c12483`.

## Temporización y selección del objetivo

| Constante | Valor | Función a 25 MHz |
|---|---:|---|
| `WAIT_CYCLES` | 75000000 | Preparación de al menos 3 s |
| `TENTH_CYCLES` | 2500000 | Ciclos por décima |
| `HOLD_CYCLES` | 25000000 | Presentación de resultado o error durante 1 s |
| `RELEASE_CYCLES` | 500000 | Liberación estable durante 20 ms |
| `ROUNDS` | 10 | Respuestas correctas por partida |

La conversión a décimas se realiza por restas sucesivas y truncamiento. El promedio es la división entera de la suma de los diez tiempos cuantizados entre diez.

La selección del objetivo mezcla un estado persistente con el residuo módulo 31 de los once bits inferiores del contador. Los tiempos de interacción del jugador afectan las muestras de las rondas siguientes. Pueden repetirse objetivos consecutivos; no se garantiza distribución uniforme.

Las constantes están definidas al comienzo de `sw/game.s`. Por ejemplo, `HOLD_CYCLES=50000000` prolonga a dos segundos la presentación del resultado y del error. Cada modificación se incorpora al bitstream al volver a ejecutar el flujo de construcción.

## Mapa de memoria

Base de periféricos: `0x80000000`.

| Offset | Acceso | Función |
|---|---|---|
| `0x00` | Escritura | Dígitos del display |
| `0x04` | Escritura | Máscara de LEDs, timestamp de inicio y armado |
| `0x08` | Lectura | Botones sincronizados |
| `0x0C` | Lectura | Contador libre de ciclos |
| `0x10` | Lectura | Timestamp de la última escritura de LEDs |
| `0x14` | Lectura | Ciclos de respuesta capturados |
| `0x18` | Lectura | Bit 4: captura válida; bits 3..0: botones capturados |

## Pruebas y resultados

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\build.ps1 test
```

Las pruebas del assembler verifican codificaciones conocidas, etiquetas, expansión de `li` y rechazo de entradas inválidas. La simulación del SoC comprueba la inicialización de `x0`, la espera inicial, errores iniciales e intermedios, diez aciertos, tiempos mostrados, promedio, variación de objetivos y reinicio.

La simulación utiliza constantes temporales reducidas en `build/sim.hex`; la imagen de FPGA conserva las constantes originales. El test bench utiliza el modelo de primitivas iCE40 incluido con Yosys.

En la construcción verificada del diseño corregido se obtuvieron 1277 de 1280 celdas lógicas, 12 de 16 bloques RAM y una frecuencia máxima estimada tras ruteo de 35,45 MHz, cumpliendo el objetivo de 25 MHz. El bitstream tiene 32220 bytes. El funcionamiento del juego se comprobó en la Go Board después de corregir el arranque.

## Limitaciones

- Los tiempos se truncan a décimas; el display satura en `99`.
- El contador de 32 bits desborda aproximadamente cada 171,8 s. Cada intervalo medido debe ser menor que ese período.
- Los botones se sincronizan y se filtra su liberación; no se exige estabilidad de 20 ms antes de capturar el primer contacto.
- La selección pseudoaleatoria no tiene garantías estadísticas ni criptográficas.
- El margen de área disponible en la HX1K es reducido.

`build/`, las cachés de Python y el JSON de símbolos son archivos regenerables. Los registros de síntesis y temporización se generan en `build/yosys.log` y `build/nextpnr.log`.

