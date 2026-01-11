-- Script de inicialização do banco de dados para o serviço de feature flags
-- Execute este script no seu RDS PostgreSQL antes de fazer o deploy do serviço

CREATE TABLE IF NOT EXISTS flags (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) UNIQUE NOT NULL, -- chave de negócio única (ex: 'enable-new-checkout')
    description TEXT,
    is_enabled BOOLEAN NOT NULL DEFAULT false, -- 'kill switch' global
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Trigger para atualizar 'updated_at' automaticamente
CREATE OR REPLACE FUNCTION trigger_set_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
$$ LANGUAGE plpgsql;

-- Remove o trigger se já existir, para evitar erro na recriação
DROP TRIGGER IF EXISTS set_timestamp ON flags;

CREATE TRIGGER set_timestamp
BEFORE UPDATE ON flags
FOR EACH ROW
EXECUTE PROCEDURE trigger_set_timestamp();
