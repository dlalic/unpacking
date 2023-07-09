CREATE TYPE role_enum AS ENUM ('user', 'admin');

CREATE TABLE users (
   id UUID PRIMARY KEY,
   name VARCHAR NOT NULL,
   email VARCHAR(254) NOT NULL UNIQUE,
   role role_enum NOT NULL,
   is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
   created_at TIMESTAMP NOT NULL DEFAULT NOW(),
   updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX user_name_idx ON users (name);
SELECT diesel_manage_updated_at('users');