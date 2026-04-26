# 🚦 Semáforo Inteligente com Modo Noturno Automático

[![PIC16F628A](https://img.shields.io/badge/Microcontroller-PIC16F628A-blue.svg)](https://www.microchip.com/en-us/product/PIC16F628A)
[![Assembly](https://img.shields.io/badge/Language-Assembly-red.svg)](https://en.wikipedia.org/wiki/Assembly_language)
[![Simulator](https://img.shields.io/badge/Simulator-PICSimLab-green.svg)](https://lcgamboa.github.io/picsimlab/)

Este projeto consiste na implementação de um sistema de controle de tráfego (semáforo) utilizando o microcontrolador **PIC16F628A**. O sistema gerencia as fases de sinalização, contagem binária de tempo e uma lógica inteligente de transição para modo noturno baseada na ociosidade da via.

---

## 🛠️ Hardware e Periféricos
* **Microcontrolador:** PIC16F628A.
* **Entradas (PORTA):**
    * `RA1`: Botão de solicitação de pedestre (Lógica Pull-up).
    * `RA2`: Botão de Reset do sistema.
* **Saídas (PORTB):**
    * `RB0-RB2`: LEDs de sinalização (Verde, Amarelo, Vermelho).
    * `RB3-RB7`: Exibição da contagem regressiva em formato binário.
* **Base de Tempo:** Timer1 configurado com Prescaler 1:8 para interrupções precisas de 100ms.

## 🧠 Funcionalidades Implementadas

### 1. Ciclo Normal de Operação
O semáforo opera em um ciclo contínuo:
* **Verde (9s)** -> **Amarelo (3s)** -> **Vermelho (6s)**.
* **Extensão de Pedestre:** Se o botão `RA1` for pressionado durante as fases verde ou amarela, o tempo da fase **Vermelha** é estendido de 6s para 9s automaticamente.

### 2. Modo Noturno Automático
O sistema monitora a utilização da via. Se o semáforo completar **3 ciclos inteiros sem nenhum acionamento de pedestre**, ele entra em **Modo de Alerta**:
* Todos os LEDs se apagam, exceto o **Amarelo**, que passa a piscar em intervalos de 500ms.
* O sistema sai deste modo e retorna ao ciclo normal imediatamente se o botão de pedestre for pressionado ou se o Reset for acionado.

### 3. Tratamento de Interrupções
Utilização de interrupções de hardware para:
* **Base de tempo:** Garantir que o tempo de cada fase seja preciso, independente do processamento principal.
* **Debounce e Varredura:** Verificação assíncrona dos botões de entrada para resposta imediata.
* **Salvamento de Contexto:** Preservação dos registradores `W` e `STATUS` durante as ISRs (*Interrupt Service Routines*).

## 📂 Estrutura do Código
* **`START`**: Configuração dos registradores de direção (`TRISA`, `TRISB`) e periféricos (`T1CON`, `INTCON`).
* **`ISR`**: Gerenciamento do Timer1 e flags de controle de pedestre.
* **`CICLO_NORMAL`**: Máquina de estados principal que controla a sequência das cores.
* **`MODO_NOTURNO`**: Rotina de baixo consumo e sinalização de alerta.
* **`CONTROLA_FASE`**: Lógica de manipulação de bits para converter o tempo decimal em saída binária para os LEDs superiores.

## 🚀 Como Simular
1. Compile o código `.asm` utilizando o **MPLAB X** ou **MPASM**.
2. Carregue o arquivo `.hex` gerado no simulador **PICSimLab** ou grave diretamente no chip.
3. Configure o clock para **HS (Cristal de alta velocidade)** conforme definido nos fuses do código.

---
**Desenvolvido por:** Marcos Vinicius de Assis & [Nome da Dupla]
**Instituição:** Faculdade UCL
**Disciplina:** Sistemas Embarcados
