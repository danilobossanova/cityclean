CREATE OR REPLACE PACKAGE CIDADELIMPA AS
    /*
    Autor: Grupo TOP
    Data: 21/04/2024
    Descrição: Esta package contém procedimentos para operações relacionadas ao projeto CIDADELIMPA
    */

    -- Constante para definir o número de dias para a data limite da coleta do lixo na lixeira
    C_DAYS_TO_LIMIT_TO_COLLECT CONSTANT NUMBER := 2;

     -- Constante para definir o limiar de ocupação alta da lixeira - Usada na Trigger que monitora o status da lixeixa.
    C_HIGH_OCCUPATION_THRESHOLD CONSTANT NUMBER := 3;


    -- Função para calcular o status com base na taxa de ocupação
    FUNCTION CALCULATE_STATUS(
        p_occupation IN NUMBER
    ) RETURN NUMBER;


    -- Function para verificar se já existe uma coleta programada para a lixeira
    FUNCTION CHECK_EXISTING_COLLECTION(
        p_trash_id IN t_st_trash.id_trash%TYPE
    ) RETURN NUMBER;




    -- Procedure que atualiza a taxa de ocupacao da Lixeira
    PROCEDURE UPDATE_TRASH_OCCUPATION(
        p_trash_id IN t_st_trash.id_trash%TYPE,
        p_new_occupation IN t_st_trash.vl_occupation%TYPE,
        p_return OUT VARCHAR2
    );


    -- Procedure para adicionar uma lixeira à fila de coleta
    PROCEDURE ADD_TO_COLLECTION_QUEUE (
        p_trash_id IN t_st_trash.id_trash%TYPE,
        p_return OUT VARCHAR2 
    );


    -- Procedure para adicionar uma coleta realizada
    PROCEDURE INSERT_COLLECTION (
        p_trash_id IN t_st_trash.id_trash%TYPE,
        p_truck_id IN t_st_truck.id_truck%TYPE,
        p_collect_date IN DATE,
        p_return OUT VARCHAR2
    );
    


END CIDADELIMPA;
/


CREATE OR REPLACE PACKAGE BODY CIDADELIMPA AS
    /*
    Autor: Grupo TOP
    Data: 21/04/2024
    Descrição: Esta package contém procedimentos para operações relacionadas ao projeto CIDADELIMPA
    */

    /*******************************************************************************************************************
    *               Implementação da function que calcula um valor pra taxa de ocupação da lixeira
    *               Esse valor faz referencia a uma chave estrangeira em uma tabela que não faz parte do escopo
    *               dessa atividade, conforme especificado nas orientações desse trabalho.
    *******************************************************************************************************************/ 
    FUNCTION CALCULATE_STATUS(
        p_occupation IN NUMBER
    ) RETURN NUMBER
    IS
        v_status NUMBER;
    BEGIN
        -- Verifica se a taxa de ocupação é menor ou igual a 0
        IF p_occupation <= 0 THEN
            -- Se for menor ou igual a 0, lança uma exceção
            RAISE_APPLICATION_ERROR(-20001, 'Erro: A taxa de ocupação deve ser um número positivo.');
        END IF;

        -- Calcula o status com base na taxa de ocupação
        v_status := CASE
                        WHEN p_occupation <= 30 THEN 1  -- Lixeira com baixa ocupação
                        WHEN p_occupation <= 49 THEN 2  -- Lixeira com ocupação moderada
                        WHEN p_occupation <= 70 THEN 3  -- Lixeira com alta ocupação
                        WHEN p_occupation <= 80 THEN 4  -- Lixeira quase cheia
                        ELSE 5  -- Lixeira cheia
                    END;

        RETURN v_status;
    EXCEPTION
        WHEN OTHERS THEN
            -- Em caso de erro, retorna 0 (valor inválido)
            RETURN 0;
    END CALCULATE_STATUS;


    /*******************************************************************************************************************
    *               Implementação da fuction que verifica se já existe uma coleta 'Em Aberto' para lixeira
    *******************************************************************************************************************/ 
    FUNCTION CHECK_EXISTING_COLLECTION(
        p_trash_id IN t_st_trash.id_trash%TYPE
    ) RETURN NUMBER
    IS
        v_count NUMBER;
    BEGIN
        -- Verifica se já existe uma coleta programada para a lixeira
        SELECT COUNT(*)
        INTO v_count
        FROM t_st_trash_to_collect
        WHERE t_st_trash_id_trash = p_trash_id AND vl_status = 1;

        RETURN v_count;
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Erro ao verificar se existe coleta programada para a lixeira: ' || SQLERRM);
            RETURN -1; -- Retorna -1 em caso de erro
    END CHECK_EXISTING_COLLECTION;





    /*******************************************************************************************************************
    *               Implementação da procedure para atualizar a taxa de ocupação das lixeiras
    *******************************************************************************************************************/ 
    PROCEDURE UPDATE_TRASH_OCCUPATION(
        p_trash_id IN t_st_trash.id_trash%TYPE,        -- ID da lixeira a ser atualizada
        p_new_occupation IN t_st_trash.vl_occupation%TYPE,   -- Nova taxa de ocupação da lixeira
        p_return OUT VARCHAR2    -- Mensagem de retorno indicando o resultado da operação
    ) AS
    BEGIN
        /*
        Autor: Grupo TOP
        Data: 21/04/2024
        Descrição: Este procedimento atualiza a taxa de ocupação das lixeiras
        */

        -- Verifica se a nova taxa de ocupação está dentro do intervalo permitido
        BEGIN
            IF p_new_occupation < 0 OR p_new_occupation > 100 THEN
                -- Se estiver fora do intervalo, lança uma exceção com uma mensagem de erro
                RAISE_APPLICATION_ERROR(-20001, 'Erro: A taxa de ocupação deve estar dentro do intervalo [0, 100].');
            END IF;

            -- Atualiza o campo vl_occupation na tabela t_st_trash
            UPDATE t_st_trash
            SET vl_occupation = p_new_occupation
            WHERE id_trash = p_trash_id;

            -- Efetua o commit para confirmar a transação
            COMMIT;

            -- Define a mensagem de retorno indicando que a atualização foi bem-sucedida
            p_return := 'Taxa de ocupação atualizada com sucesso!';
            
        -- Captura exceções geradas durante a execução do bloco anterior
        EXCEPTION
            WHEN OTHERS THEN
                -- Define a mensagem de retorno indicando que ocorreu um erro durante a operação
                p_return := 'Erro: Não foi possível atualizar a taxa de ocupação.' || SQLERRM;
        END;
    END UPDATE_TRASH_OCCUPATION;




    /*******************************************************************************************************************
    *               Implementação da procedure para colocar a lixeira na 'fila' de coletas
    *******************************************************************************************************************/ 
    PROCEDURE ADD_TO_COLLECTION_QUEUE (
        p_trash_id IN t_st_trash.id_trash%TYPE,
        p_return OUT VARCHAR2 
    )
    IS
        -- Declaração da variável para armazenar a data limite
        v_limit_date DATE;
        v_existing_collections NUMBER;
    BEGIN

        -- Verifica se já existe uma coleta programada e não realizada para essa lixeira
        v_existing_collections := nvl(CHECK_EXISTING_COLLECTION(p_trash_id),0);

        IF v_existing_collections > 0 THEN
            -- @TODO: Ponto de melhoria: Criar um alerta (email, notificação) para equipe de coleta
            
            p_return := 'Já existe uma coleta programada para esta lixeira.';
            RETURN;
        END IF;

        -- Calcula a data limite como a data atual mais o número de dias definido na constante
        v_limit_date := SYSDATE + C_DAYS_TO_LIMIT;
        
        -- Insere os dados da lixeira na tabela t_st_trash_to_collect
        INSERT INTO t_st_trash_to_collect (
            id_trash_to_collect,
            t_st_trash_id_trash,
            dt_request,
            dt_limit,
            vl_status
        )
        VALUES (
            SEQ_TRASH_TO_COLLECT.NEXTVAL,
            p_trash_id, -- id da lixeira
            SYSDATE,  -- Hoje, data que a solicitação foi feita
            v_limit_date, -- Data limite para coleta ser feita
            1 -- Status 1 representa "Em aberto"
        ); 
        
        COMMIT;

        p_return := 'Lixeira adicionada à fila de coleta com sucesso.';

    EXCEPTION
        WHEN OTHERS THEN
            p_return := 'Erro ao adicionar lixeira à fila de coleta: ' || SQLERRM;
    END ADD_TO_COLLECTION_QUEUE;


    /*******************************************************************************************************************
    *               Implementação da procedure para colocar a lixeira na 'fila' de coletas
    *******************************************************************************************************************/ 


END CIDADELIMPA;
/
