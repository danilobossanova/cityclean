CREATE OR REPLACE TRIGGER TRG_MONITOR_TRASH_STATUS_FOR_COLLECTION
AFTER INSERT OR UPDATE OF vl_status ON t_st_trash
FOR EACH ROW
DECLARE
    v_existing_collections NUMBER;

    /*
        Autor: Grupo TOP
        Data: 21/04/2024
        Descrição: Esta trigger é acionada após cada atualização do campo vl_status na tabela t_st_trash. 
                   Ela verifica se o status da lixeira é maior ou igual a 3 (C_HIGH_OCCUPATION_THRESHOLD) e coloca a 
                   lixeira na 'fila' de coleta
    */

BEGIN
    -- Verifica se o vl_status da lixeira é maior ou igual a 3

    IF :NEW.vl_status >= CIDADELIMPA.C_HIGH_OCCUPATION_THRESHOLD THEN

        -- Verifica se já existe uma coleta programada para esta lixeira
        v_existing_collections := nvl(CIDADELIMPA.CHECK_EXISTING_COLLECTION(p_trash_id),0);

        IF v_existing_collections = 0 THEN
            -- Chama a procedure para adicionar a lixeira à fila de coleta
            CIDADELIMPA.ADD_TO_COLLECTION_QUEUE(:NEW.id_trash, SYSDATE);
        ELSE
            DBMS_OUTPUT.PUT_LINE('Já existe uma coleta programada para esta lixeira.');
        END IF;
    END IF;


EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Erro ao monitorar o status da lixeira: ' || SQLERRM);
END TRG_MONITOR_TRASH_STATUS_FOR_COLLECTION;
/
