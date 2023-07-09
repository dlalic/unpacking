CREATE TABLE passwords (
   user_id UUID NOT NULL PRIMARY KEY REFERENCES users (id) ON DELETE CASCADE,
   password TEXT NOT NULL,
   created_at TIMESTAMP NOT NULL DEFAULT NOW(),
   updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

SELECT diesel_manage_updated_at('passwords');
