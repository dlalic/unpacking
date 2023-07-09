CREATE TYPE media_enum AS ENUM ('blog', 'book', 'news', 'twitter', 'video', 'website');

CREATE TABLE snippets (
   id UUID PRIMARY KEY,
   text TEXT NOT NULL,
   media media_enum NOT NULL,
   link TEXT NULL,
   created_at TIMESTAMP NOT NULL DEFAULT NOW(),
   updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX ON snippets (created_at);

SELECT diesel_manage_updated_at('snippets');
