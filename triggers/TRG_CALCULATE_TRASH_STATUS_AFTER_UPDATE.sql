CREATE OR REPLACE TRIGGER TRG_CALCULATE_TRASH_STATUS_AFTER_UPDATE
AFTER UPDATE OF vl_occupation ON t_st_trash
FOR EACH ROW
/*
Autor: Grupo TOP
Data: 21/04/2024
Descrição: Esta trigger é acionada após cada atualização do campo vl_occupation na tabela t_st_trash. 
Ela calcula o número de status com base na nova taxa de ocupação e atribui esse valor ao campo vl_status. 
A função CALCULATE_STATUS é utilizada para determinar o número de status com base na taxa de ocupação fornecida como entrada.
*/
BEGIN
    -- Tratamento de exceções para possíveis erros
    BEGIN
        -- Calcula o novo status com base na taxa de ocupação atualizada
        :NEW.vl_status := CIDADELIMPA.CALCULATE_STATUS(:NEW.vl_occupation);
        
    EXCEPTION
        WHEN OTHERS THEN
            -- Em caso de erro, define o status como 0 (inválido) e registra o erro
            :NEW.vl_status := 0;
            DBMS_OUTPUT.PUT_LINE('Erro ao calcular o status da lixeira: ' || SQLERRM);
    END;
END;
/
