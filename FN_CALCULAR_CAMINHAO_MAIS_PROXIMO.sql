CREATE OR REPLACE FUNCTION FN_CALCULAR_CAMINHAO_MAIS_PROXIMO(
    p_id_lixeira IN NUMBER
) RETURN NUMBER
/******************************************************************************
 * Autor: Danilo
 * Data: 15/04/2024
 * Descri��o: Fun��o que calcula o ID do caminh�o mais pr�ximo de uma determinada
 *            lixeira com base nas coordenadas geogr�ficas utilizando a formula
 *            de Haversine
 * Par�metros:
 *   - p_id_lixeira: ID da lixeira para a qual deseja encontrar o caminh�o mais pr�ximo.
 * Retorno:
 *   - ID do caminh�o mais pr�ximo.
 *****************************************************************************/
IS
    v_id_caminhao NUMBER;
    v_distancia_minima NUMBER;
    v_distancia_atual NUMBER;
    v_lixeira_lat NUMBER;
    v_lixeira_long NUMBER;
    v_raio_terra CONSTANT NUMBER := 6371; -- Raio m�dio da Terra em quil�metros
BEGIN
    -- Obt�m as coordenadas da lixeira a partir do JSON
    SELECT JSON_VALUE(coordenadas_json, '$.latitude'),
           JSON_VALUE(coordenadas_json, '$.longitude')
    INTO v_lixeira_lat, v_lixeira_long
    FROM lixeira
    WHERE id = p_id_lixeira;
    
    -- Inicializa a vari�vel de dist�ncia m�nima com um valor alto
    v_distancia_minima := 9999999;
    
    -- Loop pelos caminh�es para encontrar o mais pr�ximo
    FOR caminhao IN (SELECT id, ultima_coordenada_json FROM caminhao) LOOP
        -- Obt�m as coordenadas do caminh�o a partir do JSON
        DECLARE
            v_caminhao_lat NUMBER;
            v_caminhao_long NUMBER;
        BEGIN
            SELECT JSON_VALUE(caminhao.ultima_coordenada_json, '$.latitude'),
                   JSON_VALUE(caminhao.ultima_coordenada_json, '$.longitude')
            INTO v_caminhao_lat, v_caminhao_long
            FROM dual;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                -- Tratamento de exce��o caso a coordenada do caminh�o n�o seja v�lida
                CONTINUE;
        END;
        
        -- Calcula a dist�ncia entre a lixeira e o caminh�o atual usando a f�rmula de Haversine
        -- Detalhes do c�lculo:
        -- 1. Converte as coordenadas de graus para radianos
        -- 2. Calcula a diferen�a entre as longitudes e latitudes
        -- 3. Aplica a f�rmula de Haversine
        v_distancia_atual := v_raio_terra * ACOS(
            -- Multiplica o cosseno da latitude da lixeira pelo cosseno da latitude do caminh�o
            COS(RADIANS(v_lixeira_lat)) * COS(RADIANS(v_caminhao_lat)) *
            -- Calcula a diferen�a entre as longitudes do caminh�o e da lixeira
            COS(RADIANS(v_caminhao_long) - RADIANS(v_lixeira_long)) +
            -- Multiplica o seno da latitude da lixeira pelo seno da latitude do caminh�o
            SIN(RADIANS(v_lixeira_lat)) * SIN(RADIANS(v_caminhao_lat))
        );
        
        -- Se a dist�ncia atual for menor que a m�nima registrada at� agora,
        -- atualiza a dist�ncia m�nima e o ID do caminh�o mais pr�ximo
        IF v_distancia_atual < v_distancia_minima THEN
            v_distancia_minima := v_distancia_atual;
            v_id_caminhao := caminhao.id;
        END IF;
    END LOOP;
    
    -- Retorna o ID do caminh�o mais pr�ximo encontrado
    RETURN v_id_caminhao;
END;
/
