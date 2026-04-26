;==============================================================================
; PROJETO: SEMÁFORO COM MODO NOTURNO AUTOMÁTICO (UCL)
; HARDWARE: RA1=PEDESTRE, RA2=RESET, PORTB=LEDS/CONTADOR
;==============================================================================
    #INCLUDE <P16F628A.INC>

    ; Configuração dos Fuses: Define cristal de alta velocidade, desliga Watchdog,
    ; habilita pino de Reset (MCLR) e desabilita programação em baixa tensão (LVP)
    ; para liberar o pino RB4 para uso como I/O digital.
    __CONFIG _HS_OSC & _WDT_OFF & _PWRTE_ON & _MCLRE_ON & _LVP_OFF

;==============================================================================
; VARIÁVEIS NA RAM (GPR - General Purpose Registers)
;==============================================================================
    CBLOCK 0x20
        W_TEMP          ; Registrador auxiliar para salvar o valor de W na ISR
        STATUS_TEMP     ; Registrador auxiliar para salvar o valor de STATUS na ISR
        TEMPO           ; Armazena os segundos restantes na fase atual do semáforo
        ESTADO          ; Armazena a máscara de bits do LED de cor ativo (RB0-RB2)
        TICKS           ; Contador de estouros do Timer1 para formar a base de tempo
        CICLOS_SEM_PED  ; Incrementado a cada ciclo completo sem acionamento de RA1
        FLAGS           ; Registrador de status para comunicação entre ISR e Main
    ENDC

    #DEFINE F_PED_PRES   FLAGS, 0   ; Indica que o botão foi pressionado no momento
    #DEFINE F_CICLO_PED  FLAGS, 1   ; Indica se houve pedestre em algum momento do ciclo

;==============================================================================
; VETORES DE MEMÓRIA
;==============================================================================
    ORG 0x000
    GOTO START          ; Desvio para o início da configuração de hardware

    ORG 0x004
ISR:
    ; --- Salvamento de Contexto ---
    ; Salva os registradores W e STATUS para garantir que o retorno da interrupção
    ; não interfira nos cálculos do programa principal (Aula 09, pág. 57).
    MOVWF   W_TEMP
    SWAPF   STATUS, W
    MOVWF   STATUS_TEMP
    BCF     STATUS, RP0 ; Garante acesso ao Banco 0 para manipular o Timer

    ; --- Tratamento da Interrupção do Timer1 ---
    BTFSS   PIR1, TMR1IF ; Verifica se o Timer1 gerou a interrupção
    GOTO    CHECK_BTN    ; Se não foi o Timer, vai verificar o botão
    BCF     PIR1, TMR1IF ; Limpa manualmente a flag de interrupção (obrigatório)
    
    ; Recarga do Timer1 para 100ms (Base de Cálculo: Fosc/4 com Prescaler 1:8)
    MOVLW   0xCE
    MOVWF   TMR1H
    MOVLW   0xAC
    MOVWF   TMR1L

    DECFSZ  TICKS, F     ; Decrementa o contador de frações de segundo
    GOTO    CHECK_BTN    ; Se ainda não completou 1 segundo, verifica o botão
    MOVLW   .10          ; Reseta para 10 ticks (totalizando 1 segundo)
    MOVWF   TICKS
    DECF    TEMPO, F     ; Decrementa o cronômetro principal da fase

CHECK_BTN:
    ; --- Verificação Assíncrona do Botão de Pedestre RA1 ---
    ; Utiliza lógica de Pull-up: botão pressionado envia nível lógico 0.
    BTFSS   PORTA, 1
    GOTO    SET_PED      ; Se RA1 for 0, marca a solicitação
    GOTO    EXIT_ISR
SET_PED:
    BSF     F_PED_PRES   ; Flag de detecção imediata para o semáforo
    BSF     F_CICLO_PED  ; Flag de registro histórico para evitar o modo noturno

EXIT_ISR:
    ; --- Restauração de Contexto ---
    ; Devolve os valores originais aos registradores W e STATUS.
    SWAPF   STATUS_TEMP, W
    MOVWF   STATUS
    SWAPF   W_TEMP, F
    SWAPF   W_TEMP, W
    RETFIE               ; Retorna e habilita a chave global GIE

;==============================================================================
; CONFIGURAÇÃO DE PERIFÉRICOS (START)
;==============================================================================
START:
    MOVLW   0x07
    MOVWF   CMCON       ; Desliga os comparadores analógicos (Aula 10, pág. 54)
    BSF     STATUS, RP0 ; Muda para o Banco 1
    MOVLW   B'00000110' ; Configura RA1 e RA2 como entradas digitais
    MOVWF   TRISA
    CLRF    TRISB       ; Configura todo o PORTB como saída digital
    BSF     PIE1, TMR1IE; Habilita a interrupção local do Timer1
    BCF     STATUS, RP0 ; Retorna ao Banco 0
    MOVLW   B'00110000' ; Configura Prescaler do Timer1 em 1:8
    MOVWF   T1CON
    MOVLW   B'11000000' ; Habilita interrupções Globais (GIE) e Periféricas (PEIE)
    MOVWF   INTCON
    
    ; Inicialização das variáveis e pinos
    CLRF    PORTB
    CLRF    FLAGS
    CLRF    CICLOS_SEM_PED
    BSF     PORTA, 3    ; Ativa o Enable do barramento de LEDs na placa McLab1

;==============================================================================
; MÁQUINA DE ESTADOS PRINCIPAL
;==============================================================================
CICLO_NORMAL:
    BCF     F_CICLO_PED  ; Inicia a contagem de um novo ciclo para o modo noturno

    ; --- FASE VERDE (RB0) ---
    MOVLW   .9           ; Define 9 segundos de duração
    MOVWF   TEMPO
    MOVLW   B'00000001'  ; Liga bit RB0
    MOVWF   ESTADO
    CALL    CONTROLA_FASE

    ; --- FASE AMARELA (RB1) ---
    MOVLW   .3           ; Define 3 segundos de duração
    MOVWF   TEMPO
    MOVLW   B'00000010'  ; Liga bit RB1
    MOVWF   ESTADO
    CALL    CONTROLA_FASE

    ; --- FASE VERMELHA (RB2) ---
    ; Implementa o requisito de extensão do tempo para pedestres
    MOVLW   .6           ; Tempo padrão (6s)
    BTFSC   F_PED_PRES   ; Verifica se a interrupção detectou pressão no RA1
    MOVLW   .9           ; Se sim, carrega o tempo estendido (9s)
    MOVWF   TEMPO
    BCF     F_PED_PRES   ; Limpa a solicitação após atendê-la
    MOVLW   B'00000100'  ; Liga bit RB2
    MOVWF   ESTADO
    CALL    CONTROLA_FASE

    ; --- LÓGICA DE TRANSIÇÃO PARA MODO NOTURNO ---
    ; Verifica se houve qualquer pedestre durante todo o ciclo
    BTFSC   F_CICLO_PED  ; Se houve, reseta a contagem de ciclos vazios
    GOTO    RESET_CONTAGEM_CICLOS
    
    INCF    CICLOS_SEM_PED, F
    MOVLW   .3
    SUBWF   CICLOS_SEM_PED, W ; Compara se já passaram 3 ciclos ociosos
    BTFSC   STATUS, Z    ; Se o resultado da subtração for Zero, vai para modo noturno
    GOTO    MODO_NOTURNO
    GOTO    CICLO_NORMAL

RESET_CONTAGEM_CICLOS:
    CLRF    CICLOS_SEM_PED ; Reinicia o contador de ociosidade
    GOTO    CICLO_NORMAL

;==============================================================================
; MODO NOTURNO (SINALIZAÇÃO DE ALERTA)
;==============================================================================
MODO_NOTURNO:
    CLRF    PORTB
    BCF     F_PED_PRES   ; Limpa resquícios de pressão no botão
MN_LOOP:
    ; Monitoramento constante das entradas durante o repouso
    BTFSS   PORTA, 2     ; Verifica se o botão de Reset (RA2) foi acionado
    GOTO    START

    BTFSC   F_PED_PRES   ; Verifica se o pedestre solicitou a volta do semáforo
    GOTO    SAIR_NOTURNO

    ; Lógica de temporização de 500ms para o pisca-pisca
    MOVLW   .5           ; 5 ticks de 100ms
    MOVWF   TICKS
    BSF     T1CON, TMR1ON
WAIT_500MS:
    BTFSC   F_PED_PRES   ; Garante resposta imediata durante a espera
    GOTO    SAIR_NOTURNO
    BTFSS   PORTA, 2
    GOTO    START
    
    MOVLW   .5
    SUBWF   TICKS, W
    BTFSS   STATUS, Z    ; Aguarda a interrupção decrementar TICKS na ISR
    GOTO    WAIT_500MS
    
    ; Inversão de estado do Amarelo (RB1) via XOR (Aula 07, pág. 47)
    MOVLW   B'00000010'  
    XORWF   PORTB, F
    BCF     T1CON, TMR1ON ; Para o timer para reiniciar a contagem no próximo pulso
    GOTO    MN_LOOP

SAIR_NOTURNO:
    CLRF    CICLOS_SEM_PED ; Requisitos do trabalho: zerar contagem ao voltar
    BCF     F_PED_PRES
    GOTO    CICLO_NORMAL

;==============================================================================
; GESTÃO DE TEMPO E CONTAGEM BINÁRIA NO PORTB (RB3:RB7)
;==============================================================================
CONTROLA_FASE:
    MOVLW   .10          ; Prepara base de 1 segundo
    MOVWF   TICKS
    BSF     T1CON, TMR1ON ; Inicia a contagem do tempo por hardware
LOOP_FASE:
    ; --- Rotina de Deslocamento para Exibição Binária ---
    ; Desloca o valor de TEMPO (bits 0-3) para os LEDs superiores (bits 3-7)
    MOVF    TEMPO, W
    MOVWF   W_TEMP
    BCF     STATUS, C    ; Limpa o Carry para rotação limpa (Aula 07, pág. 23)
    RLF     W_TEMP, F    ; Rotaciona 3 vezes para alinhar com RB3
    RLF     W_TEMP, F
    RLF     W_TEMP, F    
    
    ; Combina a cor da fase com a contagem binária via porta lógica OU (IORWF)
    MOVF    W_TEMP, W
    IORWF   ESTADO, W
    MOVWF   PORTB        ; Atualiza simultaneamente cor e contagem binária

    BTFSS   PORTA, 2     ; Monitora o botão de Reset em tempo real
    GOTO    START

    ; Verifica se o cronômetro da fase zerou (via ISR)
    MOVF    TEMPO, F
    BTFSS   STATUS, Z    ; Testa se a flag Zero do registrador STATUS foi ativada
    GOTO    LOOP_FASE    ; Se não zerou, continua atualizando o painel
    BCF     T1CON, TMR1ON ; Desliga o timer ao encerrar a fase
    RETURN

    END                  ; Fim do código fonte