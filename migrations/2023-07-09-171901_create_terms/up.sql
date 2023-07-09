CREATE TABLE terms (
   id UUID PRIMARY KEY,
   name TEXT NOT NULL UNIQUE,
   created_at TIMESTAMP NOT NULL DEFAULT NOW(),
   updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX ON terms (created_at);

SELECT diesel_manage_updated_at('terms');

CREATE TABLE terms_related (
    term_id UUID REFERENCES terms(id),
    related_id UUID REFERENCES terms(id),
    PRIMARY KEY(term_id, related_id)
);
