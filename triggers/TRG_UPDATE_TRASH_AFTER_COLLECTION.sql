CREATE OR REPLACE TRIGGER TRG_UPDATE_TRASH_AFTER_COLLECTION
AFTER INSERT OR UPDATE ON t_st_collect
FOR EACH ROW
DECLARE

    v_trash_id t_st_collect.t_st_trash_id_trash%TYPE;
    v_retorno VARCHAR2;

    /*
        Autor: Grupo TOP
        Data: 21/04/2024
        Descrição: Essa trigger é usada para monitora quando uma coleta é feita. Após a coleta
                    na lixeira ser feita, é importante atualizar o status da coleta e a taxa de 
                    ocupação da lixeira.
    */

BEGIN
    -- Captura o id da lixeira afetada pela coleta
    v_trash_id := :NEW.t_st_trash_id_trash;

    -- Chama a procedure para zerar a taxa de ocupação da lixeira
    CIDADELIMPA.UPDATE_TRASH_OCCUPATION(v_trash_id, 0);

    -- Confirma a transação
    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Erro ao atualizar o status da lixeira após a coleta: ' || SQLERRM);
END TRG_UPDATE_TRASH_AFTER_COLLECTION;
/
