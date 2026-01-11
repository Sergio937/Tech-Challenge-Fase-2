## Validando Auth Service
# criando login
curl -X POST http://meuaplicativo.local/admin/keys -H "Content-Type: application/json" -H "Authorization: Bearer minha_master_key_super_secreta" -d '{"name": "meu-primeiro-servico"}'

#R:
# {"name":"meu-primeiro-servico","key":"tm_key_5964e2745dd8ad52d13b2678a001a113dafb9a23ae1b5d5fee92679337df95fe","message":"Guarde esta chave com segurança! Você não poderá vê-la novamente."}


# ATENÇÃO, VC PRECISA PASSAR ESSA CHAVE ( A SUA CHAVE) NO SERVIÇO evaluation-service, no compose. Ai suba novamente apenas o evaluation-service.
# atualize a variavel e use o comando kubectl apply -f ./kubernetes/local/evaluation/deployment.yaml

curl http://meuaplicativo.local/validate \
-H "Authorization: Bearer tm_key_5964e2745dd8ad52d13b2678a001a113dafb9a23ae1b5d5fee92679337df95fe"

#R
# {"message":"Chave válida"}

curl http://meuaplicativo.local/validate \
-H "Authorization: Bearer chave-errada-123"

#R
# Chave de API inválida ou inativa

## Validando Flag Service

# cria a flag
curl -X POST http://meuaplicativo.local/flags -H "Content-Type: application/json" -H "Authorization: Bearer tm_key_5964e2745dd8ad52d13b2678a001a113dafb9a23ae1b5d5fee92679337df95fe" -d '{
    "name": "enable-new-dashboard",
    "description": "Ativa o novo dashboard para usuários",
    "is_enabled": true
}'

# R
# {"created_at":"Sat, 22 Nov 2025 19:45:48 GMT","description":"Ativa o novo dashboard para usu\u00e1rios","id":1,"is_enabled":true,"name":"enable-new-dashboard","updated_at":"Sat, 22 Nov 2025 19:45:48 GMT"}

curl http://meuaplicativo.local/flags \
-H "Authorization: Bearer tm_key_5964e2745dd8ad52d13b2678a001a113dafb9a23ae1b5d5fee92679337df95fe"

# R
# [{"created_at":"Sat, 22 Nov 2025 19:45:48 GMT","description":"Ativa o novo dashboard para usu\u00e1rios","id":1,"is_enabled":true,"name":"enable-new-dashboard","updated_at":"Sat, 22 Nov 2025 19:45:48 GMT"}]

## Targeting Service

# cria regra para a flag
curl -X POST http://meuaplicativo.local/rules \
-H "Content-Type: application/json" \
-H "Authorization: Bearer tm_key_5964e2745dd8ad52d13b2678a001a113dafb9a23ae1b5d5fee92679337df95fe" \
-d '{
    "flag_name": "enable-new-dashboard",
    "is_enabled": true,
    "rules": {
        "type": "PERCENTAGE",
        "value": 50
    }
}'

#R
# {"created_at":"Sat, 22 Nov 2025 19:48:12 GMT","flag_name":"enable-new-dashboard","id":1,"is_enabled":true,"rules":{"type":"PERCENTAGE","value":50},"updated_at":"Sat, 22 Nov 2025 19:48:12 GMT"}

##  Evaluation service

# avalia
curl "http://meuaplicativo.local/evaluate?user_id=user-123&flag_name=enable-new-dashboard" 

#R
# {"flag_name":"enable-new-dashboard","user_id":"user-123","result":true}

## Analytics service

#R
#2025-11-22 21:02:07,834 - INFO - Recebidas 1 mensagens.
#2025-11-22 21:02:07,834 - INFO - Processando mensagem ID: a0840389-5d41-4726-a0e0-747873e46cc5
#2025-11-22 21:02:07,852 - INFO - Evento 44a1d448-8772-4ac7-a436-3d41c3637f6e (Flag: enable-new-dashboard) salvo no DynamoDB.







