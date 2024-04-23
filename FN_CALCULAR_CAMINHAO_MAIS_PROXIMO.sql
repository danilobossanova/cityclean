CREATE OR REPLACE FUNCTION FN_CALCULAR_CAMINHAO_MAIS_PROXIMO(
    p_id_lixeira IN NUMBER
) RETURN NUMBER
/******************************************************************************
 * Autor: Danilo
 * Data: 15/04/2024
 * Descrição: Função que calcula o ID do caminhão mais próximo de uma determinada
 *            lixeira com base nas coordenadas geográficas utilizando a formula
 *            de Haversine
 * Parâmetros:
 *   - p_id_lixeira: ID da lixeira para a qual deseja encontrar o caminhão mais próximo.
 * Retorno:
 *   - ID do caminhão mais próximo.
 *****************************************************************************/
IS
    v_id_caminhao NUMBER;
    v_distancia_minima NUMBER;
    v_distancia_atual NUMBER;
    v_lixeira_lat NUMBER;
    v_lixeira_long NUMBER;
    v_raio_terra CONSTANT NUMBER := 6371; -- Raio médio da Terra em quilômetros
BEGIN
    -- Obtém as coordenadas da lixeira a partir do JSON
    SELECT JSON_VALUE(coordenadas_json, '$.latitude'),
           JSON_VALUE(coordenadas_json, '$.longitude')
    INTO v_lixeira_lat, v_lixeira_long
    FROM lixeira
    WHERE id = p_id_lixeira;
    
    -- Inicializa a variável de distância mínima com um valor alto
    v_distancia_minima := 9999999;
    
    -- Loop pelos caminhões para encontrar o mais próximo
    FOR caminhao IN (SELECT id, ultima_coordenada_json FROM caminhao) LOOP
        -- Obtém as coordenadas do caminhão a partir do JSON
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
                -- Tratamento de exceção caso a coordenada do caminhão não seja válida
                CONTINUE;
        END;
        
        -- Calcula a distância entre a lixeira e o caminhão atual usando a fórmula de Haversine
        -- Detalhes do cálculo:
        -- 1. Converte as coordenadas de graus para radianos
        -- 2. Calcula a diferença entre as longitudes e latitudes
        -- 3. Aplica a fórmula de Haversine
        v_distancia_atual := v_raio_terra * ACOS(
            -- Multiplica o cosseno da latitude da lixeira pelo cosseno da latitude do caminhão
            COS(RADIANS(v_lixeira_lat)) * COS(RADIANS(v_caminhao_lat)) *
            -- Calcula a diferença entre as longitudes do caminhão e da lixeira
            COS(RADIANS(v_caminhao_long) - RADIANS(v_lixeira_long)) +
            -- Multiplica o seno da latitude da lixeira pelo seno da latitude do caminhão
            SIN(RADIANS(v_lixeira_lat)) * SIN(RADIANS(v_caminhao_lat))
        );
        
        -- Se a distância atual for menor que a mínima registrada até agora,
        -- atualiza a distância mínima e o ID do caminhão mais próximo
        IF v_distancia_atual < v_distancia_minima THEN
            v_distancia_minima := v_distancia_atual;
            v_id_caminhao := caminhao.id;
        END IF;
    END LOOP;
    
    -- Retorna o ID do caminhão mais próximo encontrado
    RETURN v_id_caminhao;
END;
/
