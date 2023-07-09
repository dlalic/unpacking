CREATE TABLE terms_snippets (
   term_id UUID REFERENCES terms(id),
   snippet_id UUID REFERENCES snippets(id),
   PRIMARY KEY(term_id, snippet_id)
);